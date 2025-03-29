[Linux Device Drivers 3rd Edition](https://github.com/lancetw/ebook-1/blob/master/03_operating_system/Linux%20Device%20Drivers.3rd.Edition.pdf)
by Jonathan Corbet, Alessandro Rubini, and Greg Kroah-Hartman

[GitHub repo](https://github.com/d0u9/Linux-Device-Driver/tree/master) With examples updated for Linux kernel 5.10.
This repo should be cloned into nfs_dir:
```
mkdir nfs_dir
cd nfs_dir
git@github.com:d0u9/Linux-Device-Driver.git
cd ..
```

This repo doesn't include kernel source but it can be found in the following places:
 - [Linux Archives](https://www.kernel.org/)
 - `wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.4.tar.xz`
 - [Ubuntu](https://wiki.ubuntu.com/Kernel/SourceCode)
```
mkdir kernel
cd kernel
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.4.tar.xz
cd ..
```
