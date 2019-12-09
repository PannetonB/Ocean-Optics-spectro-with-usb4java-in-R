# Premiers pas USB dans R
# Ocean Optics USB4000 avec __*usb4java*__
  
par Bernard Panneton
r Sys.Date()


# Introduction
La librairie __Java__ _usb4java_[^1] permet d'établir la communication avec un périphérique connecté via un port USB.
Dans ce document, on va illustrer l'utilisation des cette librarie pour interagir avec un spectromètre d'Ocean Optics, un
USB4000.  

[^1]: http://usb4java.org/

# Création des objets 
Il faut d'abord charger la librairie _rJava_, ajouter le chemin vers les librairies de _usb4java_ à l'aide du code suivant:
```{r}
ok = require(rJava)
.jinit()

mypath=file.path(getwd(),"../JavaLibs/usb4java-1.3.0/lib/usb4java-1.3.0.jar")
.jaddClassPath(mypath)
mypath=file.path(getwd(),"../JavaLibs/usb4java-1.3.0/lib/libusb4java-1.3.0-win32-x86-64.jar")
.jaddClassPath(mypath)


context = .jnew("org.usb4java.Context")
dlist = .jnew("org.usb4java.DeviceList")
libusb = .jnew("org.usb4java.LibUsb")
desc = .jnew("org.usb4java.DeviceDescriptor")
dhandle <- .jnew("org.usb4java.DeviceHandle")
bufutils <- .jnew("org.usb4java.BufferUtils")
```

# Recherche du spectromètre parmi les périphériques USB  
Il faut d'abord identifier notre spectromètre parmi tous les périphériques raccordés à l'ordinateur. Notre périphérique est identifiable par
le code du vendeur 0x2457 et le code du produit 0x1022.

```{r}
#on initialise l'objet libusb
res = libusb$init(context) 

#on récupère la liste de tous les périphériques USB. res donne le nombre de périphériques.
res = libusb$getDeviceList(context,dlist) 

#ce sera le numéro du périphérique USB correspondant à notre USB4000
dev_no = NULL  

#On parcoure la liste des périphériques USB pour trouver celui qui a notre nom de vendeur
#et le bon code de produit
for (k in 0:(res-1)){
  #Les infos nécessaires se trouvent dans le DeviceDescriptor
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

#On définit notre spectro
usb4000 <- dlist$get(as.integer(dev_no))

#On montre tous les champs du DeviceDescriptor
libusb$getDeviceDescriptor(usb4000,desc)
usb4000_DDesc <- desc

cat("\nDevice Descriptor du USB4000:\n")
cat(usb4000_DDesc$dump())

```


# Récupération du nom, de la version et du numéro de série du spectromètre
La fonction _libusb$getStringDescriptor_ permet de récupérer le nom de l'appareil (paramètre 2L) et sa version (paramètre 1L). La fonction 0x01 permet d'initialiser le spectromètre et la fonction 0x05 suivi du paramètre 0x00 permet de récupérer le numéro de série du spectromètre. Ces commandes de même que les adresses des _endpoint_ d'entrée et de sorties sont détaillées dans la manuel du spectromètre [^2].  
  
[^2]: USB4000-OEM-Data-Sheet.pdf qui se trouve dans le répertoire __Doc__ du projet __OceanOptics_with_usb4java_in_R.

```{r}
#On définit les commandes
init_cmd <- .jarray(as.raw(1))
queryserial_cmd <- .jarray(as.raw(c(0x05,0x00)))

#On définit les Endpoints pour les entrées et sorties.
outendp <- .jbyte(1)
inendp <- .jbyte(0x81)

#Et un timeout
tout <- .jlong(1000L)





#Start communication to USB
libusb$errorName(libusb$open(usb4000,dhandle))

#Lire le nom de l'appareil et sa version
lenom <- libusb$getStringDescriptor(dhandle,.jbyte(2L))
dev_version <- libusb$getStringDescriptor(dhandle,.jbyte(1L))




libusb$errorName(libusb$setConfiguration(dhandle,1L))
libusb$errorName(libusb$claimInterface(dhandle,0L))

#Init
#On définit les buffers d'entrée/sortie nécessaires
buffer <- bufutils$allocateByteBuffer(1L)
buffer$put(init_cmd)
transfered <- bufutils$allocateIntBuffer()
#On envoie la commande pour initialiser
libusb$errorName(libusb$bulkTransfer(dhandle,outendp,buffer,transfered,tout))

#Query serial
#On définit les buffers nécessaires pour envoyer la commande
transfered <- bufutils$allocateIntBuffer()
buffer <- bufutils$allocateByteBuffer(2L)
buffer$put(queryserial_cmd)
#Send command
libusb$errorName(libusb$bulkTransfer(dhandle,outendp,buffer,transfered,tout))

#Read serial number
#Les buffers
buffer = bufutils$allocateByteBuffer(20L)
#Lire les résultats
transfered <- bufutils$allocateIntBuffer()
libusb$errorName(libusb$bulkTransfer(dhandle,inendp,buffer,transfered,tout))

#Stop communication
libusb$errorName(libusb$releaseInterface(dhandle,0L))
libusb$close(dhandle)

buffer$rewind()
transfered$rewind()
N <- transfered$get() #nombre de bytes reçus
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


```
  
# Récupération des coefficients pour calculer les longueurs d'onde
D'après le manuel[^2], les 4 coefficients permettant de calculer le vecteur de longueurs d'onde peuvent être récupérés
à l'aide de la fonction 0x05 avec les paramètres 0x01, 0x02, 0x03 et 0x04 respectivement. On procède d'une manière similaire à ce qui a été fait pour récupérer le numéro de série:  

```{r}
getWavelengths <- function()
{
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
    #cat("Coefficient ", (k-1), ": ", dum, "\n")
    lescoeffs[k] <- as.numeric(dum)
  }
  
  p <- 0:3647
  wv <- lescoeffs[1] + lescoeffs[2]*p + lescoeffs[3]*p^2 + lescoeffs[4]*p^3
 
  
  #Stop communication
  libusb$errorName(libusb$releaseInterface(dhandle,0L))
  libusb$close(dhandle)
  
  return(wv)
}

wv <- getWavelengths()

```
  
# _Query Status_  
La fonction _Query Status_ du USB4000 permet de récupérer des informations sur le statut du capteur. La fonction plus bas récupère quelques unes des informations.  

```{r}
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

queryStatus(usb4000,dhandle,libusb,bufutils)
```
  
# Définir le temps d'intégration
On définit le temps d'intégration avec la fonction 0x02 du USB4000. La fonction demande un temps en µsec mais pour des temps d'intégration supérieurs à 655 msec, la résolution est limitée à 1 msec. Une fonction R a été créée pour définir le temps d'intégration en msec.  

```{r}


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

```

  
# Récupération d'un spectre
On est maintenant en mesure de faire l'acquisition d'un spectre avec la fonction 0x09.  

```{r, fig.width=8,fig.height=5}

revShort_2_numeric <- function(x){
  s <- bytes(as.integer(x))
  s <- gsub(" ","",s)
  s1 <- stringr::str_sub(s,-2,-1)
  sr <- paste0("0x",s1[seq(2,length(s1),2)],s1[seq(1,length(s1),2)])
  sr <- as.numeric(sr)
}


getSpectrum <- function(pack_in_spectra=15)
{
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
  libusb$errorName(libusb$bulkTransfer(dhandle,EP2in,end_buffer,transfered,tout))
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

setIntegrationTime(temps=100,usb4000,dhandle,bufutils,libusb)
wv <- getWavelengths()
range(wv)
dum <- getSpectrum()

{
  plot(wv,dum[22:3669],type="l",col="red",lwd=2)
}
```

   
A la fin, on détruit la liste.  

```{r}
libusb$freeDeviceList(dlist,TRUE)
```

  

[^2]: USB4000-OEM-Data-Sheet.pdf qui se trouve dans le répertoire __Doc__ du projet __OceanOptics_with_usb4java_in_R.