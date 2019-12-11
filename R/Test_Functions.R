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

setIntegrationTime(500,usbObjects,usbDevice$usbDevice)
(statut <- queryStatus(usbObjects, usbDevice$usbDevice))


dum <- getSpectrum(pack_in_spectra=15, usbObjects, usbDevice$usbDevice)

windows()
{
  ptm=proc.time()
  for (k in 1:20){
    setIntegrationTime(10+k*5,usbObjects,usbDevice$usbDevice)
    dum <- getSpectrum(pack_in_spectra=15, usbObjects, usbDevice$usbDevice)
    plot(wv, dum[22:3669],type="l",col="red",lwd=2,ylim=c(0,50000))
  }
  (proc.time()-ptm)
}


plot(wv, dum[22:3669],type="l",col="red",lwd=2)


sp <- get_N_Spectrum(pack_in_spectra=15, nspectra=20, usbObjects, usbDevice$usbDevice)
plot(wv,sp[22:3669],type="l",col="red",lwd=2,
     main = paste0(name_serial$name, " - Serial number: ", name_serial$serialno),
     xlab = "Wavelength [nm]",
     ylab = "Intensity [A.U.]")

free_Device(usbObjects)


rm(list=ls())
