#Testing functions

source("R/playWith_usb4java.R")

usbObjects <- init_usb()

product=0x1022
vendor=0x2457
usbDevice <- find_usb(product,vendor,usbObjects,TRUE)

cmdList <- get_command_set(product)

usbDevice <- c(usbDevice, cmdList)

name_serial <- get_OO_name_n_serial(usbObjects, usbDevice)

lapply(name_serial, print)

wv <- getWavelengths(usbObjects, usbDevice)

statut <- queryStatus(usbObjects, usbDevice)

(getMaxSatLevel(usbObjects, usbDevice))

setIntegrationTime(100,usbObjects,usbDevice)
(statut <- queryStatus(usbObjects, usbDevice))


dum <- getSpectrum(usbObjects, usbDevice)

plot(wv, dum[22:3669],type="l",col="lightgreen",lwd=5)
lines(wv, boxcar(dum[22:3669],10), col="black",lwd=1)
legend("topleft",legend=c("Raw","Boxcar"),lty=c(1,1),col=c("green","black"),
         inset = c(0.05,0.05))

windows()
{
  ptm=proc.time()
  for (k in 1:20){
    setIntegrationTime(10+k*5,usbObjects,usbDevice)
    dum <- getSpectrum(usbObjects, usbDevice)
    plot(wv, boxcar(dum[22:3669],5),type="l",col="red",lwd=2,ylim=c(0,50000))
  }
  (proc.time()-ptm)
}

dev.off()

plot(wv, dum[22:3669],type="l",col="red",lwd=2)

setIntegrationTime(100,usbObjects,usbDevice)
{
  ptm=proc.time()
  sp <- get_N_Spectrum(nspectra=20, usbObjects, usbDevice)
  (proc.time()-ptm)
}

plot(wv,sp[22:3669],type="l",col="red",lwd=2,
     main = paste0(name_serial$name, " - Serial number: ", name_serial$serialno),
     xlab = "Wavelength [nm]",
     ylab = "Intensity [A.U.]")

free_Device(usbObjects)


rm(list=ls())
