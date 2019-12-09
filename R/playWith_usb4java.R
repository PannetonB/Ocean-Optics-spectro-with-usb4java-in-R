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

#Lire le nom de l'appareil et sa version
libusb$errorName(libusb$open(usb4000,dhandle))
lenom <- libusb$getStringDescriptor(dhandle,.jbyte(2L))
dev_version <- libusb$getStringDescriptor(dhandle,.jbyte(1L))
libusb$close(dhandle)


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
no_serie <- character()
for (k in 2:N){
 no_serie <- paste0(no_serie,(intToUtf8(buffer$get())))
}

cat("\n***************\n",
    "\nLe spectro est: ",
    "\n",lenom,
    "\n",dev_version,
    "\n",no_serie,
    "\n***************\n")

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

#Java bytes are signed!
jbyte_2_uint <- function(x){
  indi <- which(sign(x)<0)
  x[indi] <- 256+x
  x
}


#Query status
queryStatus <- function(usb4000,dhandle,libusb,bufutils){
  #Start communication to USB
  libusb$errorName(libusb$open(usb4000,dhandle))
  libusb$errorName(libusb$setConfiguration(dhandle,1L))
  libusb$errorName(libusb$claimInterface(dhandle,0L))
  
  transfered <- bufutils$allocateIntBuffer()
  cmd_buffer <- bufutils$allocateByteBuffer(1L)
  cmd_buffer$put(.jarray(as.raw(0xFE)))
  status_buffer <- bufutils$allocateByteBuffer(16L)
  
  outendp <- .jbyte(1)
  inendp <- .jbyte(0x81)
  tout <- .jlong(1000L)
  
  libusb$errorName(libusb$bulkTransfer(dhandle,outendp,cmd_buffer,transfered,tout))
  libusb$errorName(libusb$bulkTransfer(dhandle,inendp,status_buffer,transfered,tout))
  
  #Stop communication
  libusb$errorName(libusb$releaseInterface(dhandle,0L))
  libusb$close(dhandle)
  
  nb_pix <- 256*jbyte_2_uint(status_buffer$get(1L)) + jbyte_2_uint(status_buffer$get(0L))
  int_time <- jbyte_2_uint(status_buffer$get(2L)) +
    jbyte_2_uint(status_buffer$get(3L))*256 +
    jbyte_2_uint(status_buffer$get(4L))*256*256 +
    jbyte_2_uint(status_buffer$get(5L))*256^3
  int_time <- round(int_time/1000)  #msec
  pack_in_spectra <- jbyte_2_uint(status_buffer$get(9L))
  pack_count <- jbyte_2_uint(status_buffer$get(11L))
  usb_speed <- jbyte_2_uint(status_buffer$get(14L))
  if (usb_speed==0){
    usb_speed <- "full"
  }else
  {
    usb_speed <- "high"
  }
  
  return(list(nb_pix=nb_pix,
              int_time=int_time,
              pack_in_spectra=pack_in_spectra,
              pack_count=pack_count,
              usb_speed=usb_speed))
}

revShort_2_numeric <- function(x){
  s <- bytes(as.integer(x))
  s <- gsub(" ","",s)
  s1 <- str_sub(s,-2,-1)
  sr <- paste0("0x",s1[seq(2,length(s1),2)],s1[seq(1,length(s1),2)])
  sr <- as.numeric(sr)
}


setIntegrationTime <- function(temps,usb4000,dhandle,bufutils,libusb){
  library(pryr)
  letemps = round(temps)*1000
  temps_byte <- bytes(as.integer(letemps))
  temps_byte <- unlist(strsplit(temps_byte," "))
  temps_byte <- paste0("0x",temps_byte)
  temps_hword <- rev(as.raw(temps_byte))
  
  cmd_intTime <- .jarray(.jbyte(c(0x02,temps_hword)))
  
  
  #Start communication to USB
  libusb$errorName(libusb$open(usb4000,dhandle))
  libusb$errorName(libusb$setConfiguration(dhandle,1L))
  libusb$errorName(libusb$claimInterface(dhandle,0L))
  
  transfered <- bufutils$allocateIntBuffer()
  cmd_buffer <- bufutils$allocateByteBuffer(5L)
  cmd_buffer$put(cmd_intTime)
  
  outendp <- .jbyte(1)
  inendp <- .jbyte(0x81)
  tout <- .jlong(1000L)
  
  libusb$errorName(libusb$bulkTransfer(dhandle,outendp,cmd_buffer,transfered,tout))
  
  
  #Stop communication
  libusb$errorName(libusb$releaseInterface(dhandle,0L))
  libusb$close(dhandle)
  
}

setIntegrationTime(temps=50.2,usb4000,dhandle,bufutils,libusb)
queryStatus(usb4000,dhandle,libusb,bufutils)


getSpectrum <- function(pack_in_spectra=15)
{
  library(stringr)
  #Start communication to USB
  libusb$errorName(libusb$open(usb4000,dhandle))
  libusb$errorName(libusb$setConfiguration(dhandle,1L))
  libusb$errorName(libusb$claimInterface(dhandle,0L))
  
  transfered <- bufutils$allocateIntBuffer()
  cmd_buffer <- bufutils$allocateByteBuffer(1L)
  cmd_buffer$put(.jarray(as.raw(0x09)))
  data_buffer_1 <- bufutils$allocateByteBuffer(4L*512L)
  data_buffer_2 <- bufutils$allocateByteBuffer(11L*512L)
  end_buffer <- bufutils$allocateByteBuffer(1L)
  
  outendp <- .jbyte(1)
  EP6in <- .jbyte(0x86)
  EP2in <- .jbyte(0x82)
  tout <- .jlong(5000L)
  
  libusb$errorName(libusb$bulkTransfer(dhandle,outendp,cmd_buffer,transfered,tout))
  
  
 
  libusb$errorName(libusb$bulkTransfer(dhandle,EP6in,data_buffer_1,transfered,tout))
  libusb$errorName(libusb$bulkTransfer(dhandle,EP2in,data_buffer_2,transfered,tout))
  libusb$errorName(libusb$bulkTransfer(dhandle,EP2in,data_buffer,transfered,tout))
  dum1 <- .jarray(raw(2048))
  data_buffer_1$get(dum1,0L,(4L*512L))
  dum2 <- .jarray(raw(11*512))
  data_buffer_2$get(dum2,0L,(11L*512L))
  
  dum <- c(.jevalArray(dum1),.jevalArray(dum2))
    
 
  #Stop communication
  libusb$errorName(libusb$releaseInterface(dhandle,0L))
  libusb$close(dhandle)
  sp=revShort_2_numeric(dum)
  return(sp)
}

setIntegrationTime(temps=30,usb4000,dhandle,bufutils,libusb)
wv <- getWavelengths()
dum <- getSpectrum()

plot(dum,type="l",col="red",lwd=2)
lines(dum[22:3669],type="l",col="blue",lwd=2)
libusb$freeDeviceList(dlist,TRUE)

windows()
ptm <- proc.time()
for (k in 1:10){
  #setIntegrationTime(temps=30+k,usb4000,dhandle,bufutils,libusb)  
  dum <- getSpectrum()
 # plot(wv,dum[22:3669],type="l",col="red",lwd=2, ylim=c(0,30000))
}
proc.time()-ptm

