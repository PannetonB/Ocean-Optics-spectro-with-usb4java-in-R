ok = require(rJava)
.jinit()

mypath=file.path(getwd(),"JavaLibs/usb4java-1.3.0/lib/usb4java-1.3.0.jar")
.jaddClassPath(mypath)
mypath=file.path(getwd(),"JavaLibs/usb4java-1.3.0/lib/libusb4java-1.3.0-win32-x86-64.jar")
.jaddClassPath(mypath)


context = .jnew("org.usb4java.Context")
dlist = .jnew("org.usb4java.DeviceList")
libusb = .jnew("org.usb4java.LibUsb")
desc = .jnew("org.usb4java.DeviceDescriptor")
dhandle <- .jnew("org.usb4java.DeviceHandle")
bufutils <- .jnew("org.usb4java.BufferUtils")



res=libusb$init(context)
res = libusb$getDeviceList(context,dlist)

dev_no = NULL

for (k in 0:(res-1)){
  libusb$getDeviceDescriptor(dlist$get(as.integer(k)),desc)
  p=desc$idProduct()
  v=desc$idVendor()
  cat("Product: Ox", sprintf("%X",p)," - Vendor: Ox")
  cat(sprintf("%X",v))
  if (p==0x1022 & v==0x2457){
    cat("  - ***************Device ",k," is Ocean Optics!********")
    dev_no=k
  }
  cat("\n")
}
#USB4000 is vendor: Ox2457 and product: Ox1022, that is device 12

usb4000 <- dlist$get(as.integer(dev_no))
libusb$getDeviceDescriptor(usb4000,desc)
usb4000_DDesc <- desc


cat(usb4000_DDesc$dump())




buffer <- bufutils$allocateByteBuffer(1L)
init_cmd <- .jarray(as.raw(1))
queryserial_cmd <- .jarray(as.raw(c(0x05,0x00)))


transfered <- bufutils$allocateIntBuffer()
outendp <- .jbyte(1)
inendp <- .jbyte(0x81)
tout <- .jlong(1000L)

#Start communication to USB
libusb$errorName(libusb$open(usb4000,dhandle))
libusb$errorName(libusb$setConfiguration(dhandle,1L))
libusb$errorName(libusb$claimInterface(dhandle,0L))

#Init
libusb$errorName(libusb$bulkTransfer(dhandle,outendp,buffer,transfered,tout))
#Query serial
transfered <- bufutils$allocateIntBuffer()
buffer <- bufutils$allocateByteBuffer(2L)
buffer$put(queryserial_cmd)
#Send command
libusb$errorName(libusb$bulkTransfer(dhandle,outendp,buffer,transfered,tout))

#Read serial number
buffer = bufutils$allocateByteBuffer(20L)
transfered <- bufutils$allocateIntBuffer()
libusb$errorName(libusb$bulkTransfer(dhandle,inendp,buffer,transfered,tout))

#Stop communication
libusb$errorName(libusb$releaseInterface(dhandle,0L))
libusb$close(dhandle)

buffer$rewind()
transfered$rewind()
N <- transfered$get()
buffer$get()   #first is 0x05
cat("Serial number is: ")
for (k in 2:N){
  cat(intToUtf8(buffer$get()))
}
cat("\n")

#On définit les commandes
wv_cal_0_cmd <- .jarray(as.raw(c(0x05,0x01)))
wv_cal_1_cmd <- .jarray(as.raw(c(0x05,0x02)))
wv_cal_2_cmd <- .jarray(as.raw(c(0x05,0x03)))
wv_cal_3_cmd <- .jarray(as.raw(c(0x05,0x04)))
lescmds <- list(wv_cal_0_cmd,wv_cal_1_cmd,wv_cal_2_cmd,wv_cal_3_cmd)

#Start communication to USB
libusb$errorName(libusb$open(usb4000,dhandle))
libusb$errorName(libusb$setConfiguration(dhandle,1L))
libusb$errorName(libusb$claimInterface(dhandle,0L))

#On définit les buffers nécessaires pour envoyer la commande
transfered <- bufutils$allocateIntBuffer()
cmd_buffer <- bufutils$allocateByteBuffer(2L)
coeff_buffer <- bufutils$allocateByteBuffer(20L)

tout_read <- .jlong(3000L)
lescoeffs <- numeric(4)

for (k in 1:4){
  cmd_buffer$rewind()
  cmd_buffer$put(lescmds[[k]])
  #Send command
  libusb$errorName(libusb$bulkTransfer(dhandle,outendp,cmd_buffer,transfered,tout))
  coeff_buffer$rewind()
  transfered$rewind()
  #Lire
  libusb$errorName(libusb$bulkTransfer(dhandle,inendp,coeff_buffer,transfered,tout))
  coeff_buffer$rewind()
  transfered$rewind()
  N <- transfered$get() #nombre de bytes reçus
  coeff_buffer$get()   #first is 0x05
  coeff_buffer$get()   #second is a configuration index which is the parameter of 0x05 command.
  dum=character()
  for (i in 2:N){
    dum=paste0(dum,intToUtf8(coeff_buffer$get()))
  }
  cat("Coefficient ", (k-1), ": ", dum, "\n")
  lescoeffs[k] <- as.numeric(dum)
}

p <- 0:3647
wv <- lescoeffs[1] + lescoeffs[2]*p + lescoeffs[3]*p^2 + lescoeffs[4]*p^3
range(wv)

#Stop communication
libusb$errorName(libusb$releaseInterface(dhandle,0L))
libusb$close(dhandle)

libusb$freeDeviceList(dlist,TRUE)

