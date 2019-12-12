init_usb <- function(){
# -----------------------------------
# Initialize usb device:
#     1. load required library 
#     2. init JVM
#     3. Set Java class paths
#     4. Define some objects 
# RETURN:
#     a list of 4 components:
#       1. context: a Java object of class org.usb4java.Context
#       2. dlist: a Java object of class org.usb4java.DeviceList
#       3. libusb: a Java object of class org.usb4java.LibUsb
#       4. bufutils: a Java object of class org.usb4java.BufferUtils
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------

  ok = require(rJava)
  if (!ok){
    install.packages("rJava")
    library(rJava)
  }
  ok=require(pryr)
  if (!ok){
    install.packages("pryr")
    library(pryr)
  }
  ok=require(stringr)
  if (!ok){
    install.packages("stringr")
    library(stringr)
  }
  ok=require(inline)
  if (!ok){
    install.packages("inline")
    library(inline)
  }
  
  #Init. Java JVM
  .jinit()
  
   # set Java library paths 
   mypath=file.path(getwd(),"JavaLibs/usb4java-1.3.0/lib/usb4java-1.3.0.jar")
  .jaddClassPath(mypath)
  mypath=file.path(getwd(),"JavaLibs/usb4java-1.3.0/lib/libusb4java-1.3.0-win32-x86-64.jar")
  .jaddClassPath(mypath)
  
  #Define required objects
  context = .jnew("org.usb4java.Context")
  dlist = .jnew("org.usb4java.DeviceList")
  libusb = .jnew("org.usb4java.LibUsb")
  bufutils <- .jnew("org.usb4java.BufferUtils")
  
  
  source(file.path(getwd(),'R/Cfunc_littleEndian_2bytes_2_integer.R'))
  
  
  return(list(context = context,
              dlist = dlist,
              libusb = libusb,
              bufutils = bufutils))
}
# -----------------------------------
find_usb <- function(product,vendor,usbObjects, silent=TRUE){
# -----------------------------------  
# Given a vendor and a product ID number, find the corresponding
# USB device.  
# 
# INPUTS:
#   product: product ID number  
#   vendor: vendor ID number  
#   usbObjects: list returned by init_usb
#   silent: when TRUE, no output at console.  
#   
# OUTPUTS:
#   a list with 2 components:
#     1. usbDevice: the device as obtained with dlist$get(as.integer(dev_no))
#        where dlist was defined in init_usb
#     2. usbDescription: obtained by libusb$DeviceDescriptor(usbDevice, usbDescription)
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------   
  
  with(usbObjects,{
    desc = .jnew("org.usb4java.DeviceDescriptor")
    
    devlist <- dlist
    
    res=libusb$init(context)
    res = libusb$getDeviceList(context,devlist)
    dlist <<- devlist
    
    dev_no = NULL
   
    for (k in 0:(res-1)){
      libusb$getDeviceDescriptor(dlist$get(as.integer(k)),desc)
      p=desc$idProduct()
      v=desc$idVendor()
      if (!silent){
        cat("Product: Ox", sprintf("%X",p)," - Vendor: Ox")
        cat(sprintf("%X",v))
      }
      if (p==product & v==vendor){
        if (!silent) cat("  - ***************Device ",k," is Ocean Optics!********")
        dev_no=k
      }
      if (!silent) cat("\n")
    }
    #USB4000 is vendor: Ox2457 and product: Ox1022, that is device 12
   
    
    
    usb4000 <<- dlist$get(as.integer(dev_no))
    libusb$getDeviceDescriptor(usb4000,desc)
    usb4000_DDesc <<- desc
  })
  
  return(list(usbDevice = usb4000, usbDescription = usb4000_DDesc))
}


# -----------------------------------
get_OO_name_n_serial <- function(usbObjects, usbDevice){
# -----------------------------------  
# Function to get device name and version, device serial number and company names.  
# INPUTS:
#   usbObjects: the list returned by init_usb()
#   usbDevice:  the list returned by find_usb()
# OUTPUTS:
#   a list with 3 components:
#     1. name: name of the USB device
#     2. version: name of device with version number  
#     3. serialno: serial number
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------  
  with(usbObjects,{  
    dhandle <- .jnew("org.usb4java.DeviceHandle")
    
    #Lire le nom de l'appareil et sa version
    libusb$errorName(libusb$open(usbDevice,dhandle))
   
    lenom <<- libusb$getStringDescriptor(dhandle,.jbyte(2L))
    dev_version <<-libusb$getStringDescriptor(dhandle,.jbyte(1L))
    
    
    buffer <-bufutils$allocateByteBuffer(1L)
    init_cmd <- .jarray(as.raw(1))
    queryserial_cmd <- .jarray(as.raw(c(0x05,0x00)))
    
    
    transfered <-bufutils$allocateIntBuffer()
    outendp <- .jbyte(1)
    inendp <- .jbyte(0x81)
    tout <- .jlong(1000L)
    
    #Start communication to USB
    libusb$errorName(libusb$setConfiguration(dhandle,1L))
    libusb$errorName(libusb$claimInterface(dhandle,0L))
  
    #Init
    libusb$errorName(libusb$bulkTransfer(dhandle,outendp,buffer,transfered,tout))
    #Query serial
    transfered <- bufutils$allocateIntBuffer()
    buffer <-bufutils$allocateByteBuffer(2L)
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
    no_serie <<- character()
    for (k in 2:N){
     no_serie <<- paste0(no_serie,(intToUtf8(buffer$get())))
    }
  })
  
 return(list(name=lenom, version=dev_version, serialno=no_serie))
}
# -----------------------------------
getWavelengths <- function(usbObjects, usbDevice){
# -----------------------------------
# To get the wavelength vector by reading the wavelength calibration coefficients  
# INPUTS:
#   usbObjects: the list returned by init_usb()
#   usbDevice:  the list returned by find_usb()
# OUTPUTS:
#   a vector of wavelengths
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------  

  with(usbObjects,{
    dhandle <- .jnew("org.usb4java.DeviceHandle")
    
    #On définit les commandes
    wv_cal_0_cmd <- .jarray(as.raw(c(0x05,0x01)))
    wv_cal_1_cmd <- .jarray(as.raw(c(0x05,0x02)))
    wv_cal_2_cmd <- .jarray(as.raw(c(0x05,0x03)))
    wv_cal_3_cmd <- .jarray(as.raw(c(0x05,0x04)))
    lescmds <- list(wv_cal_0_cmd,wv_cal_1_cmd,wv_cal_2_cmd,wv_cal_3_cmd)
    
    #Start communication to USB
    libusb$errorName(libusb$open(usbDevice,dhandle))
    libusb$errorName(libusb$setConfiguration(dhandle,1L))
    libusb$errorName(libusb$claimInterface(dhandle,0L))
    
    #On définit les buffers nécessaires pour envoyer la commande
    transfered <- bufutils$allocateIntBuffer()
    cmd_buffer <- bufutils$allocateByteBuffer(2L)
    coeff_buffer <- bufutils$allocateByteBuffer(20L)
    
    tout_read <- .jlong(3000L)
    lescoeffs <- numeric(4)
    
    outendp <- .jbyte(1)
    inendp <- .jbyte(0x81)
    tout <- .jlong(1000L)
    
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
      #cat("Coefficient ", (k-1), ": ", dum, "\n")
      lescoeffs[k] <- as.numeric(dum)
    }
    
    p <- 0:3647
    wv <<- lescoeffs[1] + lescoeffs[2]*p + lescoeffs[3]*p^2 + lescoeffs[4]*p^3
    
    
    #Stop communication
    libusb$errorName(libusb$releaseInterface(dhandle,0L))
    libusb$close(dhandle)
  })
  
  return(wv)
}
# -----------------------------------
#Java bytes are signed!
jbyte_2_uint <- function(x){
# -----------------------------------
# Takes a vector of Java bytes and interprets and 0:255 
# INPUTS:
#   x: vector of Java bytes as seen in R
# OUTPUTS:
#   a vector of value in the range 0:255, same length as input.
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------  

  indi <- which(sign(x)<0)
  x[indi] <- 256+x
  x
}

# -----------------------------------
#Query status
queryStatus <- function(usbObjects, usbDevice){
# -----------------------------------
# Query the USB device status. 
  # INPUTS:
  #   usbObjects: the list returned by init_usb()
  #   usbDevice:  the list returned by find_usb()
# OUTPUTS:
#   a list of 5 elements:
        # 1. nb_pix: number of pixels in spectrum
        # 2. int_time: current integration time
        # 3. pack_in_spectra: number of data packets per spectrum
        # 4. pack_count: 
        # 5. usb_speed: speed of USB transfer ("full" or "high")
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------    
  with(usbObjects,{
  
    dhandle <- .jnew("org.usb4java.DeviceHandle")
    
    #Start communication to USB
    libusb$errorName(libusb$open(usbDevice,dhandle))
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
    
    nb_pix <<- 256*jbyte_2_uint(status_buffer$get(1L)) + jbyte_2_uint(status_buffer$get(0L))
    int_time <<- jbyte_2_uint(status_buffer$get(2L)) +
      jbyte_2_uint(status_buffer$get(3L))*256 +
      jbyte_2_uint(status_buffer$get(4L))*256*256 +
      jbyte_2_uint(status_buffer$get(5L))*256^3
    int_time <<- round(int_time/1000)  #msec
    pack_in_spectra <<- jbyte_2_uint(status_buffer$get(9L))
    pack_count <<- jbyte_2_uint(status_buffer$get(11L))
    usb_speed <<- jbyte_2_uint(status_buffer$get(14L))
    if (usb_speed==0){
      usb_speed <<- "full"
    }else
    {
      usb_speed <<- "high"
    }
  })
  
  return(list(nb_pix=nb_pix,
              int_time=int_time,
              pack_in_spectra=pack_in_spectra,
              pack_count=pack_count,
              usb_speed=usb_speed))
}


# -----------------------------------
setIntegrationTime <- function(temps,usbObjects, usbDevice){
# -----------------------------------
# Function to set spectrometer integration time. 
# INPUTS:
#   temps: integration time in msec.  
#   usbObjects: the list returned by init_usb()
#   usbDevice:  the list returned by find_usb()
# OUTPUTS: 
#     none
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------   
  
  with(usbObjects,{
  
    dhandle <- .jnew("org.usb4java.DeviceHandle")
    
    letemps = round(temps)*1000
    temps_byte <- bytes(as.integer(letemps))
    temps_byte <- unlist(strsplit(temps_byte," "))
    temps_byte <- paste0("0x",temps_byte)
    temps_hword <- rev(as.raw(temps_byte))
    
    cmd_intTime <- .jarray(.jbyte(c(0x02,temps_hword)))
    
    
    #Start communication to USB
    libusb$errorName(libusb$open(usbDevice,dhandle))
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
  })
  
}

# -----------------------------------
boxcar <- function(x, n = 5){
  # -----------------------------------
  # Apply boxcar (moving average filter) to vector. 
  # INPUTS:
  #   x: vector to smooth
  #   n: half width of averaging window. n elements on each side
  #      of middle value.
  # OUTPUTS: 
  #     a smoothed vector.
  # -----------------------------------
  # B. Panneton - pannetonb2gmail.com
  # December 2019 
  # -----------------------------------   
  
  stats::filter(x, rep(1 / n, n), sides = 2)
}

# -----------------------------------
getSpectrum <- function(pack_in_spectra=15, usbObjects, usbDevice){
# -----------------------------------
# Function to retrieve a spectrum. 
# INPUTS:
#   pack_in_spectra: number of data packets per spectrum  
#   usbObjects: the list returned by init_usb()
#   usbDevice:  the list returned by find_usb()
# OUTPUTS: 
#     a spectrum as a numeric vector.
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------     
 
  with(usbObjects,{
  
    dhandle <- .jnew("org.usb4java.DeviceHandle")
     
    #Start communication to USB
    libusb$errorName(libusb$open(usbDevice,dhandle))
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
    libusb$errorName(libusb$bulkTransfer(dhandle,EP2in,end_buffer,transfered,tout))
    dum1 <- .jarray(raw(2048))
    data_buffer_1$get(dum1,0L,(4L*512L))
    dum2 <- .jarray(raw(11*512))
    data_buffer_2$get(dum2,0L,(11L*512L))
    
    dum <- c(.jevalArray(dum1),.jevalArray(dum2))
      
   
    #Stop communication
    libusb$errorName(libusb$releaseInterface(dhandle,0L))
    libusb$close(dhandle)
    sp <<- getLittleEndianIntegerFromByteArray(dum)
  })
  return(sp)
}

# -----------------------------------
get_N_Spectrum <- function(pack_in_spectra=15, nspectra=2, usbObjects, usbDevice){
# -----------------------------------
# Function to retrieve a spectrum made as an average over a number of spectra. 
# INPUTS:
#   pack_in_spectra: number of data packets per spectrum  
#   nspectra: number of spectrum to average over.  
#   usbObjects: the list returned by init_usb()
#   usbDevice:  the list returned by find_usb()
# OUTPUTS: 
#     a spectrum as a numeric vector.
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------     
  
  with(usbObjects,{
  
    dhandle <- .jnew("org.usb4java.DeviceHandle")
    
    dum <- vector(mode="list",length=nspectra)
    
    #Start communication to USB
    libusb$errorName(libusb$open(usbDevice,dhandle))
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
    
    
    dum1 <- .jarray(raw(2048))
    dum2 <- .jarray(raw(11*512))
    
    for (k in 1:nspectra){
      libusb$errorName(libusb$bulkTransfer(dhandle,outendp,cmd_buffer,transfered,tout))
    
      libusb$errorName(libusb$bulkTransfer(dhandle,EP6in,data_buffer_1,transfered,tout))
      libusb$errorName(libusb$bulkTransfer(dhandle,EP2in,data_buffer_2,transfered,tout))
      libusb$errorName(libusb$bulkTransfer(dhandle,EP2in,end_buffer,transfered,tout))
      
      data_buffer_1$get(dum1,0L,(4L*512L))
      data_buffer_2$get(dum2,0L,(11L*512L))
      
      data_buffer_1$rewind()
      data_buffer_2$rewind()
      end_buffer$rewind()
    
      dum[[k]] <- c(.jevalArray(dum1),.jevalArray(dum2))
    }
    
    #Stop communication
    libusb$errorName(libusb$releaseInterface(dhandle,0L))
    libusb$close(dhandle)
    sp <<- lapply(dum,getLittleEndianIntegerFromByteArray)
    sp <<- colMeans(matrix(unlist(sp),nrow=nspectra,byrow=T))
  })
  
  return(sp)
}

# -----------------------------------
free_Device <- function(usbObjects){
# -----------------------------------
  usbObjects$libusb$freeDeviceList(usbObjects$dlist,TRUE)
}


