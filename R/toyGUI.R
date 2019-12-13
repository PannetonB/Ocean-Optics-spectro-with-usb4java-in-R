library(gWidgets2)
#For RGtk2 interface
options("guiToolkit"="RGtk2")

mymain = gwindow("Toy example - USB4000", visible=F, 
                 handler=function(h,...){
                   free_Device(usbObjects)
                   })

maingroup = ggroup(container = mymain, horizontal = T)

leftgroup = ggroup(container = maingroup, horizontal = F)

IDfrm <- gframe("Spectro ID",container=leftgroup, spacing=20)
IDtext <- gtext("Spectro ID",width = 150, height=100,container = IDfrm)

gseparator(container=leftgroup)

Setfrm<- gframe("Acquisition parameters", container = leftgroup,horizontal = F, spacing=20)
glabel("Number of scans", container = Setfrm)
nscansld <- gslider(1, 100, 1, value=1, container = Setfrm)
glabel("Integration time (msec)", container = Setfrm)
intTimesld <- gslider(10,2000,1,value = 50, container = Setfrm)



ggra = ggraphics(container = maingroup,expand=T)


visible(mymain) <- T


visible(ggra) <- TRUE
plot(1:1,1:1)

source("R/playWith_usb4java.R")

Acquiring <- FALSE

usbObjects <- init_usb()

product=0x1022
vendor=0x2457
usbDevice <- find_usb(product,vendor,usbObjects,TRUE)
name_serial <- get_OO_name_n_serial(usbObjects, usbDevice$usbDevice)
dispose(IDtext)
insert(IDtext," ")
lapply(name_serial, function(x) insert(IDtext,x,font.attr = list(weight="bold")))


