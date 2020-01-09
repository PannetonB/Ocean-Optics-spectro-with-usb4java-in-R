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
    #USB4000 is vendor: Ox2457 and product: Ox1022
   
    
    
    usb4000 <<- dlist$get(as.integer(dev_no))
    libusb$getDeviceDescriptor(usb4000,desc)
    usb4000_DDesc <<- desc
  })
  
  return(list(usbDevice = usb4000, usbDescription = usb4000_DDesc))
}


# -----------------------------------
get_command_set <- function(product){
  # -----------------------------------  
  # Given a product ID number, returns a list of commands defined in a file.
  # 
  # INPUTS:
  #   product: product ID number  
  #   
  # OUTPUTS:
  #   a list of commands
  # -----------------------------------
  # B. Panneton - pannetonb2gmail.com
  # December 2019 
  # -----------------------------------   
  
  products = c(0x1022, # USB4000
          #     0x1022, # Flame T
               0x101e  # Flame S
  )
  
  def_files = c("USB4000.R","FlameS.R")
  
  indi = which(products==product)[1]
  
  dumenv = new.env()
  
  source(file.path(getwd(),"Device_def", def_files[indi]), local = dumenv)
  
  cmd_list <- mget(ls(envir=dumenv),envir = dumenv)
  
  return(cmd_list)
}


# -----------------------------------
do_command <- function(usbObjects, usbDevice, cmd){
# Excute a command.
# 
# INPUTS:
#   usbObjects: the list returned by init_usb()
#   usbDevice :  the list returned by find_usb()
#         cmd :  one member of the list of commands for usbDevice
# -----------------------------------  
# OUTPUTS:
#   a list returned buffer(s) content
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------   
  with(usbObjects,{  
    dhandle <- .jnew("org.usb4java.DeviceHandle")
    libusb$errorName(libusb$open(usbDevice,dhandle))
    
    cmd_buffer <-bufutils$allocateByteBuffer(cmd$cmd$length)
    cmd_buffer$put(cmd$cmd) 
    
    transfered <-bufutils$allocateIntBuffer()
    outendp <- cmd$outEndPoint
    tout <- .jlong(1000L)
    
    n_outputs = 0
    if (!is.null(cmd$inEndPoint)){
      n_outputs <- length(cmd$inEndPoint)
    }
    
     #Start communication to USB
    libusb$errorName(libusb$setConfiguration(dhandle,1L))
    libusb$errorName(libusb$claimInterface(dhandle,0L))
    
    #Send command
    libusb$errorName(libusb$bulkTransfer(dhandle,outendp,cmd_buffer,transfered,tout))
    
    #Read back
    outBuffers <<- list()
    transBuffers <<- list()
    if (n_outputs>0){
      for (k in 1:n_outputs){
        outBuffers <<- c(outBuffers,bufutils$allocateByteBuffer(cmd$inLength[[k]]))
        transBuffers <<- c(transBuffers,bufutils$allocateIntBuffer())
        libusb$errorName(libusb$bulkTransfer(dhandle,cmd$inEndPoint[[k]],outBuffers[[k]],transBuffers[[k]],tout))
      }
    }
   
    #Stop communication
    libusb$errorName(libusb$releaseInterface(dhandle,0L))
    libusb$close(dhandle)
  })
  return(list(outbuf=outBuffers,transbuf=transBuffers))
}

# -----------------------------------
get_OO_name_n_serial <- function(usbObjects, usbDevice){
# -----------------------------------  
# Function to get device name and version, device serial number and company names.  
# INPUTS:
#   usbObjects: the list returned by init_usb()
#   usbDevice:  the list returned by 
#               c(find_usb(product,vendor,usbObjects,TRUE), get_command_set(product))
#
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
    libusb$errorName(libusb$open(usbDevice$usbDevice,dhandle))
   
    lenom <<- libusb$getStringDescriptor(dhandle,.jbyte(2L))
    dev_version <<-libusb$getStringDescriptor(dhandle,.jbyte(1L))
    #Stop communication
    libusb$errorName(libusb$releaseInterface(dhandle,0L))
    libusb$close(dhandle)
  })
  
  buffers <- do_command(usbObjects,usbDevice$usbDevice,usbDevice$queryserial_cmd)
  buffer <- buffers$outbuf[[1]]
  buffer$rewind()
  transbuf <- buffers$transbuf[[1]]
  N <- transbuf$get(0L)
  buffer$get()   #first is 0x05
  no_serie <<- character()
  for (k in 2:N){
    no_serie <<- paste0(no_serie,(intToUtf8(buffer$get())))
  }
  return(list(name=lenom, version=dev_version, serialno=no_serie))
}
# -----------------------------------
getWavelengths <- function(usbObjects, usbDevice){
# -----------------------------------
# To get the wavelength vector by reading the wavelength calibration coefficients  
# INPUTS:
#   usbObjects: the list returned by init_usb()
#   usbDevice:  the list returned by 
#               c(find_usb(product,vendor,usbObjects,TRUE), get_command_set(product))
# OUTPUTS:
#   a vector of wavelengths
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------  

  lescmds <- list(usbDevice$wv_cal_0_cmd,
                  usbDevice$wv_cal_1_cmd,
                  usbDevice$wv_cal_2_cmd,
                  usbDevice$wv_cal_3_cmd)
  
  lescoeffs <- numeric(4)
  res <- lapply(lescmds, function(x) do_command(usbObjects,usbDevice$usbDevice, x))
  
  for (k in 1:4){
    datbuf <- res[[k]]$outbuf[[1]]
    transbuf <- res[[k]]$transbuf[[1]]
    N <- transbuf$get(0L) #nombre de bytes reçus
    datbuf$get()   #first is 0x05
    datbuf$get()   #second is a configuration index which is the parameter of 0x05 command.
        dum=character()
        for (i in 2:N){
          dum=paste0(dum,intToUtf8(datbuf$get()))
        }
        #cat("Coefficient ", (k-1), ": ", dum, "\n")
        lescoeffs[k] <- as.numeric(dum)
  }
  p <- 0:(length(usbDevice$useable_pix_range)-1)
  wv <<- lescoeffs[1] + lescoeffs[2]*p + lescoeffs[3]*p^2 + lescoeffs[4]*p^3
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
#Read the maximum saturation level from register
getMaxSatLevel <- function(usbObjects, usbDevice){
  # -----------------------------------
  # Read the maximum saturation level from register 
  # INPUTS:
  #   usbObjects: the list returned by init_usb()
  #   usbDevice:  the list returned by 
  #               c(find_usb(product,vendor,usbObjects,TRUE), get_command_set(product))
  # OUTPUTS:
  #   an integer giving the maximum saturation level.
  # -----------------------------------
  # B. Panneton - pannetonb2gmail.com
  # December 2019 
  # -----------------------------------    
  res <- do_command(usbObjects,usbDevice$usbDevice,usbDevice$maxSatLevel_cmd)
  transfered <- res$transbuf[[1]]
  data_buffer <- res$outbuf[[1]]
  dum1 <- .jarray(raw(transfered$get(0L)))
  data_buffer$get(dum1,0L,3L)
  dum <- .jevalArray(dum1)
  dum <- getLittleEndianIntegerFromByteArray(dum[-1])
  
  return(dum)
}
  

# -----------------------------------
#set the maximum saturation level in register
setMaxSatLevel <- function(usbObjects, usbDevice, level){
  # -----------------------------------
  # Read the maximum saturation level from register 
  # INPUTS:
  #   usbObjects: the list returned by init_usb()
  #   usbDevice:  the list returned by find_usb()
  #   level: max level (0xFFFF for USB4000 is the maximum value)
  # OUTPUTS:
  #   an integer giving the maximum saturation level.
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
    cmd_buffer <- bufutils$allocateByteBuffer(4L)
    msb <- level %/% 256
    lsb <- level %% 256
    cmd_buffer$put(.jarray(as.raw(c(0x6a,0x80,lsb,msb))))
    data_buffer <- bufutils$allocateByteBuffer(3L)
    
    outendp <- .jbyte(0x01)
    inendp <- .jbyte(0x81)
    tout <- .jlong(1000L)
    
    libusb$errorName(libusb$bulkTransfer(dhandle,outendp,cmd_buffer,transfered,tout))
    Sys.sleep(0.001)
    
    
    #Stop communication
    libusb$errorName(libusb$releaseInterface(dhandle,0L))
    libusb$close(dhandle)
    
    
  })
  dum=getMaxSatLevel(usbObjects,usbDevice)
  
  return(dum)
}


# -----------------------------------
#Query status
queryStatus <- function(usbObjects, usbDevice){
# -----------------------------------
# Query the USB device status. 
  # INPUTS:
  #   usbObjects: the list returned by init_usb()
  #   usbDevice:  the list returned by 
  #               c(find_usb(product,vendor,usbObjects,TRUE), get_command_set(product))
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
  res <- do_command(usbObjects,usbDevice$usbDevice,usbDevice$queryStatus_cmd)
  transfered <- res$transbuf[[1]]
  status_buffer <- res$outbuf[[1]] 
  
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
#   usbDevice:  the list returned by 
#               c(find_usb(product,vendor,usbObjects,TRUE), get_command_set(product))
# OUTPUTS: 
#     none
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------   
  dum <- .jevalArray(usbDevice$setIntegrationTime_cmd$cmd)
  letemps = round(temps)*1000
  temps_byte <- bytes(as.integer(letemps))
  temps_byte <- unlist(strsplit(temps_byte," "))
  temps_byte <- paste0("0x",temps_byte)
  temps_hword <- rev(as.raw(temps_byte))
  usbDevice$setIntegrationTime_cmd$cmd <- .jarray(.jbyte(c(dum[1],temps_hword)))
  
  res <- do_command(usbObjects,usbDevice$usbDevice, usbDevice$setIntegrationTime_cmd)
  
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
getSpectrum <- function(usbObjects, usbDevice){
# -----------------------------------
# Function to retrieve a spectrum. 
# INPUTS:  
#   usbObjects: the list returned by init_usb()
#   usbDevice:  the list returned by 
#               c(find_usb(product,vendor,usbObjects,TRUE), get_command_set(product))
# OUTPUTS: 
#     a spectrum as a numeric vector.
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------     
 
  res <- do_command(usbObjects,usbDevice$usbDevice,usbDevice$getSpectrum_cmd)
  
  
  
  dum1 <- .jarray(raw(usbDevice$getSpectrum_cmd$inLength[[1]]))
  res$outbuf[[1]]$get(dum1,0L,(usbDevice$getSpectrum_cmd$inLength[[1]]))
  dum2 <- .jarray(raw(usbDevice$getSpectrum_cmd$inLength[[2]]))
  res$outbuf[[2]]$get(dum2,0L,(usbDevice$getSpectrum_cmd$inLength[[2]]))
  
  dum <- c(.jevalArray(dum1),.jevalArray(dum2))
  
  sp <- getLittleEndianIntegerFromByteArray(dum)
  
  return(sp[usbDevice$useable_pix_range])
}
  

# -----------------------------------
get_N_Spectrum <- function(nspectra=2, usbObjects, usbDevice){
# -----------------------------------
# Function to retrieve a spectrum made as an average over a number of spectra. 
# INPUTS:  
#   nspectra: number of spectrum to average over.  
#   usbObjects: the list returned by init_usb()
#   usbDevice:  the list returned by 
#               c(find_usb(product,vendor,usbObjects,TRUE), get_command_set(product))
# OUTPUTS: 
#     a spectrum as a numeric vector.
# -----------------------------------
# B. Panneton - pannetonb2gmail.com
# December 2019 
# -----------------------------------     
  dum <- vector(mode="list",length=nspectra)
  for (k in 1:nspectra){
    res <- do_command(usbObjects,usbDevice$usbDevice,usbDevice$getSpectrum_cmd)
    dum1 <- .jarray(raw(usbDevice$getSpectrum_cmd$inLength[[1]]))
    res$outbuf[[1]]$get(dum1,0L,(usbDevice$getSpectrum_cmd$inLength[[1]]))
    dum2 <- .jarray(raw(usbDevice$getSpectrum_cmd$inLength[[2]]))
    res$outbuf[[2]]$get(dum2,0L,(usbDevice$getSpectrum_cmd$inLength[[2]]))
    dum[[k]] <- c(.jevalArray(dum1),.jevalArray(dum2))
  }
  sp <- lapply(dum,getLittleEndianIntegerFromByteArray)
  sp <- colMeans(matrix(unlist(sp),nrow=nspectra,byrow=T))
  return(sp[usbDevice$useable_pix_range])
}

# -----------------------------------
free_Device <- function(usbObjects){
# -----------------------------------
  usbObjects$libusb$freeDeviceList(usbObjects$dlist,TRUE)
}


