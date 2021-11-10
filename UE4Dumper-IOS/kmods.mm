#include "kmods.h"
#include "Offsets.h"
#include "SDK.h"
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach/machine/thread_status.h>
#include <pthread.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <string.h>
#import <mach-o/dyld.h>
#import <mach/vm_region.h>
#import <malloc/malloc.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <mach/mach_traps.h>
#include <mach-o/dyld.h>
//#import <Foundation/NSProcessInfo.h>
#include "proc_info.h"
#include "libproc.h"
#import "Mem.h"

using namespace std;
extern mach_port_t task;
const char *short_options = "hlrfnsabcdvi:j:p:o:g:u:w:";
const struct option long_options[] = {
        {"help",       no_argument,       nullptr, 'h'},
        {"lib",        no_argument,       nullptr, 'l'},
        {"raw",        no_argument,       nullptr, 'r'},
        {"fast",       no_argument,       nullptr, 'f'},
        {"package",    required_argument, nullptr, 'p'},
        {"output",     required_argument, nullptr, 'o'},
        {"gname",      required_argument, nullptr, 'g'},
        {"guobj",      required_argument, nullptr, 'u'},
        {"gworld",     required_argument, nullptr, 'w'},
        {"objs",       no_argument,       nullptr, 'n'},
        {"strings",    no_argument,       nullptr, 's'},
        {"sdku",       no_argument,       nullptr, 'a'},
        {"sdkw",       no_argument,       nullptr, 'b'},
        {"newue",      no_argument,       nullptr, 'c'},
        {"actors",     no_argument,       nullptr, 'd'},
        {"verbose",    no_argument,       nullptr, 'v'},
        {"derefgname", required_argument, nullptr, 'i'},
        {"derefguobj", required_argument, nullptr, 'j'},
        {nullptr, 0,                      nullptr, 0}
};

void Usage() {
    printf("UE4Dumper v0.18 <==> Made By KMODs(kp7742)\n");
    printf("IOS support by xinja(Xinja#8947)\n");
    printf("Usage: ./ue4dumper <option(s)>\n");
    printf("Dump Lib libUE4.so from Memory of Game Process and Generate structure SDK for UE4 Engine\n");
    printf("Tested on PUBG Mobile Series and Other UE4 Based Games\n");
    printf(" Options:\n");
    printf("--SDK Dump With GObjectArray Args--------------------------------------------------------\n");
    printf("  --sdku                              Dump SDK with GUObject\n");
    printf("  --gname <address>                   GNames Pointer Address\n");
    printf("  --guobj <address>                   GUObject Pointer Address\n");
    printf("--SDK Dump With GWorld Args--------------------------------------------------------------\n");
    printf("  --sdkw                              Dump SDK with GWorld\n");
    printf("  --gname <address>                   GNames Pointer Address\n");
    printf("  --gworld <address>                  GWorld Pointer Address\n");
    printf("--Dump Strings Args----------------------------------------------------------------------\n");
    printf("  --strings                           Dump Strings\n");
    printf("  --gname <address>                   GNames Pointer Address\n");
    printf("--Dump Objects Args----------------------------------------------------------------------\n");
    printf("  --objs                              Dumping Object List\n");
    printf("  --gname <address>                   GNames Pointer Address\n");
    printf("  --guobj <address>                   GUObject Pointer Address\n");
    printf("--Lib Dump Args--------------------------------------------------------------------------\n");
    printf("  --lib                               Dump libUE4.so from Memory\n");
    printf("  --raw(Optional)                     Output Raw Lib and Not Rebuild It\n");
    printf("  --fast(Optional)                    Enable Fast Dumping(May Miss Some Bytes in Dump)\n");
    printf("--Show ActorList With GWorld Args--------------------------------------------------------\n");
    printf("  --actors                            Show Actors with GWorld\n");
    printf("  --gname <address>                   GNames Pointer Address\n");
    printf("  --gworld <address>                  GWorld Pointer Address\n");
    printf("--Other Args-----------------------------------------------------------------------------\n");
    printf("  --newue(Optional)                   Run in UE 4.23+ Mode\n");
    printf("  --verbose(Optional)                 Show Verbose Output of Dumping\n");
    printf("  --derefgname(Optional) <true/false> De-Reference GNames Address(Default: true)\n");
    printf("  --derefguobj(Optional) <true/false> De-Reference GUObject Address(Default: false)\n");
    printf("  --package <packageName>             Binary Name of App(Default: ShooterGame)\n");
    printf("  --output <outputPath>               File Output path(Default: /var/mobile/)\n");
    printf("  --help                              Display this information\n");
}

kaddr getHexAddr(const char *addr) {
#ifndef __SO64__
    return (kaddr) strtoul(addr, nullptr, 16);
#else
    return (kaddr) strtoull(addr, nullptr, 16);
#endif
}

pid_t getprocpid(const char *proc) {
        size_t length = 0;
        static const int name[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
        int err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1, NULL, &length, NULL, 0);
        if (err == -1)
        {
            err = errno;
        }
        if (err == 0)
        {
            struct kinfo_proc *procBuffer = (struct kinfo_proc *)malloc(length);
            if(procBuffer == NULL)
            {
                return -1;
            }

            sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1, procBuffer, &length, NULL, 0);

            int count = (int)length / sizeof(struct kinfo_proc);
            for (int i = 0; i < count; ++i)
            {
                const char *procname = procBuffer[i].kp_proc.p_comm;
                if (strstr(procname, proc))
                {
                    return procBuffer[i].kp_proc.p_pid;
                }
            }
        }
        return -1;
    }




int main(int argc, char *argv[]) {
    setuid(0);
    setgid(0);
    int c;
    string outputpath("/var/mobile");
    bool isValidArg = true,
            isLibDump = false,
            isFastDump = false,
            isRawDump = false,
            isObjsDump = false,
            isStrDump = false,
            isSdkDump = false,
            isSdkDump2 = false,
            isActorDump = false;

    while ((c = getopt_long(argc, argv, short_options, long_options, nullptr)) != -1) {
        switch (c) {
            case 'l':
                isLibDump = true;
                break;
            case 'r':
                isRawDump = true;
                break;
            case 'f':
                isFastDump = true;
                break;
            case 'p':
                pkg = optarg;
                break;
            case 'o':
                outputpath = optarg;
                break;
            case 'g':
                Offsets::GNames = getHexAddr(optarg);
                break;
            case 'u':
                Offsets::GUObjectArray = getHexAddr(optarg);
                break;
            case 'w':
                Offsets::GWorld = getHexAddr(optarg);
                break;
            case 'n':
                isObjsDump = true;
                break;
            case 's':
                isStrDump = true;
                break;
            case 'a':
                isSdkDump = true;
                break;
            case 'b':
                isSdkDump2 = true;
                break;
            case 'c':
                isUE423 = true;
                break;
            case 'd':
                isActorDump = true;
                break;
            case 'v':
                isVerbose = true;
                break;
            case 'i':
                deRefGNames = isEqual(optarg, "true");
                break;
            case 'j':
                deRefGUObjectArray = isEqual(optarg, "true");
                break;
            default:
                isValidArg = false;
                break;
        }
    }

#if defined(__LP64__)
    Offsets::initOffsets_64();
    if (isUE423) {
        Offsets::patchUE423_64();
    }
    Offsets::patchCustom_64();
#else
    Offsets::initOffsets_32();
    if (isUE423) {
        Offsets::patchUE423_32();
    }
    Offsets::patchCustom_32();
#endif

    if (!isValidArg ||
        (!isLibDump && !isObjsDump && !isStrDump && !isSdkDump && !isSdkDump2 && !isActorDump)) {
        printf("Wrong Arguments, Please Check!!\n");
        Usage();
        return -1;
    }

    //Find PID

    target_pid = getprocpid(pkg.c_str());
    if (target_pid == -1) {
        cout << "Can't find the process" << endl;
        return -1;
    }
    cout << "Process name: " << pkg.c_str() << ", Pid: " << target_pid << endl ;

    kern_return_t kret;
    
    kret = task_for_pid(mach_task_self(), target_pid, &task);
    if (kret!=KERN_SUCCESS) exit(0);

    uint64_t addr = 0;
    struct proc_regioninfo region_info;
    
    kret = proc_pidinfo(target_pid, PROC_PIDREGIONINFO, addr, &region_info, sizeof(region_info));
    libbase = region_info.pri_address;
    
    const char *lib_name = pkg.c_str();
    if (libbase == 0) {
        cout << "Can't find Library: " << lib_name << endl;
        return -1;
    }
    cout << "Base Address of " << lib_name << " Found At " << setbase(16) << libbase << setbase(10)
         << endl;

    if (isLibDump) {
        //Lib End Address
        kaddr start_addr = libbase;
        kaddr end_addr = get_module_end(lib_name);
        if (end_addr == 0) {
            cout << "Can't find End of Library: " << lib_name << endl;
            return -1;
        }
        cout << "End Address of " << lib_name << " Found At " << setbase(16) << end_addr
             << setbase(10) << endl;

        //Lib Dump
        size_t libsize = (end_addr - libbase);
        cout << "Lib Size: " << libsize << endl;

        if (isRawDump) {
            ofstream rdump(outputpath + "/" + lib_name, ofstream::out | ofstream::binary);
            if (rdump.is_open()) {
                if (isFastDump) {
                    auto *buffer = new uint8_t[libsize];
                    memset(buffer, '\0', libsize);
                    vm_readv((void *) start_addr, buffer, libsize);
                    rdump.write((char *) buffer, libsize);
                } else {
                    char *buffer = new char[1];
                    while (libsize != 0) {
                        vm_readv((void *) (start_addr++), buffer, 1);
                        rdump.write(buffer, 1);
                        --libsize;
                    }
                }
            } else {
                cout << "Can't Output File" << endl;
                return -1;
            }
            rdump.close();
        } else {
            string tempPath = outputpath + "/KTemp.dat";

            ofstream ldump(tempPath, ofstream::out | ofstream::binary);
            if (ldump.is_open()) {
                if (isFastDump) {
                    auto *buffer = new uint8_t[libsize];
                    memset(buffer, '\0', libsize);
                    vm_readv((void *) start_addr, buffer, libsize);
                    ldump.write((char *) buffer, libsize);
                } else {
                    char *buffer = new char[1];
                    while (libsize != 0) {
                        vm_readv((void *) (start_addr++), buffer, 1);
                        ldump.write(buffer, 1);
                        --libsize;
                    }
                }
            } else {
                cout << "Can't Output File" << endl;
                return -1;
            }
            ldump.close();

            //SoFixer Code//
            cout << "Rebuilding Elf(So)" << endl;

#if defined(__LP64__)
            string outPath = outputpath + "/" + lib_name;

            fix_so(tempPath.c_str(), outPath.c_str(), start_addr);
#else
            ElfReader elf_reader;

            elf_reader.setDumpSoFile(true);
            elf_reader.setDumpSoBaseAddr(start_addr);

            auto file = fopen(tempPath.c_str(), "rb");
            if (nullptr == file) {
                printf("source so file cannot found!!!\n");
                return -1;
            }
            auto fd = fileno(file);

            elf_reader.setSource(tempPath.c_str(), fd);

            if (!elf_reader.Load()) {
                printf("source so file is invalid\n");
                return -1;
            }

            ElfRebuilder elf_rebuilder(&elf_reader);
            if (!elf_rebuilder.Rebuild()) {
                printf("error occured in rebuilding elf file\n");
                return -1;
            }
            fclose(file);
            //SoFixer Code//

            ofstream redump(outputpath + "/" + lib_name, ofstream::out | ofstream::binary);
            if (redump.is_open()) {
                redump.write((char*) elf_rebuilder.getRebuildData(), elf_rebuilder.getRebuildSize());
            } else {
                cout << "Can't Output File" << endl;
                return -1;
            }
            redump.close();
#endif

            cout << "Rebuilding Complete" << endl;
            remove(tempPath.c_str());
        }
    }

    if (isStrDump) {
        if (Offsets::GNames < 1) {
            printf("Please Enter Correct GName Addresses!!\n");
            Usage();
            return -1;
        }
        DumpStrings(outputpath);
        cout << endl;
    }
    if (isObjsDump) {
        if (Offsets::GUObjectArray < 1) {
            printf("Please Enter Correct GUObject Addresses!!\n");
            Usage();
            return -1;
        }
        DumpObjects(outputpath);
        cout << endl;
    }
    if (isSdkDump) {
        if (Offsets::GNames < 1 || Offsets::GUObjectArray < 1) {
            printf("Please Enter Correct GName and GUObject Addresses!!\n");
            Usage();
            return -1;
        }
        DumpSDK(outputpath);
        cout << endl;
    }
    if (isSdkDump2) {
        if (Offsets::GNames < 1 || Offsets::GWorld < 1) {
            printf("Please Enter Correct GName and GWorld Addresses!!\n");
            Usage();
            return -1;
        }
        DumpSDKW(outputpath);
        cout << endl;
    }
    if (isActorDump) {
        if (Offsets::GNames < 1 || Offsets::GWorld < 1) {
            printf("Please Enter Correct GName and GWorld Addresses!!\n");
            Usage();
            return -1;
        }
        DumpActors();
        cout << endl;
    }
    return 0;
}






