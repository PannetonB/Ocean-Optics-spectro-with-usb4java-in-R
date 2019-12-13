#Testing functions

source("R/playWith_usb4java.R")

usbObjects <- init_usb()

product=0x1022
vendor=0x2457
usbDevice <- find_usb(product,vendor,usbObjects,TRUE)

name_serial <- get_OO_name_n_serial(usbObjects, usbDevice$usbDevice)

lapply(name_serial, print)

wv <- getWavelengths(usbObjects, usbDevice$usbDevice)

statut <- queryStatus(usbObjects, usbDevice$usbDevice)

(getMaxSatLevel(usbObjects, usbDevice$usbDevice))
(setMaxSatLevel(usbObjects,usbDevice$usbDevice,32000))

setIntegrationTime(600,usbObjects,usbDevice$usbDevice)
(statut <- queryStatus(usbObjects, usbDevice$usbDevice))


dum <- getSpectrum(pack_in_spectra=15, usbObjects, usbDevice$usbDevice)

plot(wv, dum[22:3669],type="l",col="lightgreen",lwd=5)
lines(wv, boxcar(dum[22:3669],10), col="black",lwd=1)
legend("topleft",legend=c("Raw","Boxcar"),lty=c(1,1),col=c("green","black"),
         inset = c(0.05,0.05))

windows()
{
  ptm=proc.time()
  for (k in 1:20){
    setIntegrationTime(10+k*5,usbObjects,usbDevice$usbDevice)
    dum <- getSpectrum(pack_in_spectra=15, usbObjects, usbDevice$usbDevice)
    plot(wv, boxcar(dum[22:3669],5),type="l",col="red",lwd=2,ylim=c(0,50000))
  }
  (proc.time()-ptm)
}

dev.off()

plot(wv, dum[22:3669],type="l",col="red",lwd=2)


sp <- get_N_Spectrum(pack_in_spectra=15, nspectra=20, usbObjects, usbDevice$usbDevice)
plot(wv,sp[22:3669],type="l",col="red",lwd=2,
     main = paste0(name_serial$name, " - Serial number: ", name_serial$serialno),
     xlab = "Wavelength [nm]",
     ylab = "Intensity [A.U.]")

free_Device(usbObjects)


rm(list=ls())
