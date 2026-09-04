#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/attr.h>
#include <sys/clonefile.h>
#include <copyfile.h>
static void flags(const char *tag, const char *p){ struct stat st; if(lstat(p,&st)==0) printf("  %s: st_flags=0x%x dataless=%d size=%lld blocks=%lld\n",tag,st.st_flags,(st.st_flags&SF_DATALESS)!=0,(long long)st.st_size,(long long)st.st_blocks); else printf("  %s: lstat errno=%d %s\n",tag,errno,strerror(errno)); }
static void try_mmap(const char *tag,int fd,size_t sz){ void *m=mmap(NULL,sz,PROT_READ,MAP_SHARED,fd,0); if(m==MAP_FAILED) printf("  %s: mmap FAILED errno=%d %s\n",tag,errno,strerror(errno)); else { printf("  %s: mmap ok\n",tag); munmap(m,sz);} }
static void try_read(const char *tag,int fd){ char b[16]; ssize_t n=pread(fd,b,sizeof b,0); if(n<0) printf("  %s: pread FAILED errno=%d %s\n",tag,errno,strerror(errno)); else printf("  %s: pread ok n=%zd\n",tag,n); }
int main(int argc,char**argv){ const char*p=argv[1]; int mode=argc>2?atoi(argv[2]):0;
 printf("getiopolicy(process)=%d thread=%d\n",getiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES,IOPOL_SCOPE_PROCESS),getiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES,IOPOL_SCOPE_THREAD));
 if(mode==1){ int r=setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES,IOPOL_SCOPE_PROCESS,IOPOL_MATERIALIZE_DATALESS_FILES_ON); printf("setiopolicy ON -> %d; now=%d\n",r,getiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES,IOPOL_SCOPE_PROCESS)); }
 if(mode==2){ int r=setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES,IOPOL_SCOPE_PROCESS,IOPOL_MATERIALIZE_DATALESS_FILES_OFF); printf("setiopolicy OFF -> %d; now=%d\n",r,getiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES,IOPOL_SCOPE_PROCESS)); }
 flags("before",p);
 struct attrlist al; memset(&al,0,sizeof al); al.bitmapcount=ATTR_BIT_MAP_COUNT; al.commonattr=ATTR_CMN_FLAGS; char buf[64]; int ga=getattrlist(p,&al,buf,sizeof buf,0); printf("  getattrlist: %d errno=%d\n",ga,ga?errno:0);
 int fd=open(p,O_RDONLY); if(fd<0){printf("  open FAILED errno=%d %s\n",errno,strerror(errno)); return 1;} printf("  open ok\n"); flags("after-open",p);
 struct stat st; fstat(fd,&st);
 int nc=fcntl(fd,F_NOCACHE,1); printf("  fcntl F_NOCACHE -> %d\n",nc);
 if(mode==5||mode==6){ int r=setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES,IOPOL_SCOPE_PROCESS,IOPOL_MATERIALIZE_DATALESS_FILES_OFF); printf("setiopolicy OFF -> %d; now=%d\n",r,getiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES,IOPOL_SCOPE_PROCESS)); }
 if(mode==6){ char dst[4096]; snprintf(dst,sizeof dst,"%s.copytest",p); int r=copyfile(p,dst,NULL,COPYFILE_ALL); printf("  copyfile(COPYFILE_ALL) -> %d errno=%d %s\n",r,r?errno:0,r?strerror(errno):""); flags("after-copyfile",p); if(r==0) unlink(dst); return 0; }
 if(mode==3||mode==5){ /* clonefile with default policy */ char dst[4096]; snprintf(dst,sizeof dst,"%s.clonetest",p); int r=clonefile(p,dst,0); printf("  clonefile -> %d errno=%d %s\n",r,r?errno:0,r?strerror(errno):""); flags("after-clonefile",p); if(r==0) unlink(dst); return 0; }
 try_mmap("mmap",fd,st.st_size?st.st_size:1); flags("after-mmap",p);
 if(mode!=4){ try_read("pread",fd); flags("after-read",p);} 
 close(fd); return 0; }
