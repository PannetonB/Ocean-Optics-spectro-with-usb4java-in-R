toyGUI <- function(){
  ok = require(gWidgets2)
  if (!ok){
    install.packages("gWidgets2")
    library(gWidgets2)
  } 
  #For RGtk2 interface
  options("guiToolkit"="RGtk2")
  
  
  startbtn_handler <- function(h,...)
  {
    enabled(h$obj) <- FALSE
    enabled(Stopbtn) <- TRUE 
    Acquiring <<- TRUE
    oldIntTime <- svalue(intTimesld)
    setIntegrationTime(oldIntTime,usbObjects,usbDevice)
    
    while(Acquiring){
      if (svalue(intTimesld) != oldIntTime){
        oldIntTime <- svalue(intTimesld)
        setIntegrationTime(oldIntTime,usbObjects,usbDevice)
      }
      nscans <- svalue(nscansld)
      if (nscans == 1){
        sp <- getSpectrum(usbObjects,usbDevice)
      }else
      {
        sp <- get_N_Spectrum(nscans,usbObjects,usbDevice)
      }
      visible(ggra) <- TRUE
      if (svalue(autoscaleY)){
        if (max(sp)  < satLevel){
          plot(wv, sp,type="l",col="blue",
               xlab = "Wavelength (nm)",
               ylab = "Intensity (A.U.)")
        }else
        {
          plot(wv, sp,type="l",col="red",
               xlab = "Wavelength (nm)",
               ylab = "Intensity (A.U.)")
        }
      }else
      {
        if (max(sp)  < satLevel){
          plot(wv, sp,type="l",col="blue",ylim=c(0,satLevel),
               xlab = "Wavelength (nm)",
               ylab = "Intensity (A.U.)")
        }else
        {
          plot(wv, sp,type="l",col="red",ylim=c(0,satLevel),
               xlab = "Wavelength (nm)",
               ylab = "Intensity (A.U.)")
        }
      }
      if (svalue(gridon)) grid()
    }
   enabled(Stopbtn) <- FALSE
   enabled(h$obj) <- TRUE
  }
  
  
  stopbtn_handler <- function(h,...){
    Acquiring <<- FALSE
  }
  
  mymain = gwindow("Toy example - USB4000", visible=F, 
                   handler=function(h,...){
                     Acquiring <<- FALSE
                     Sys.sleep(1)
                     free_Device(usbObjects)
                     })
  
  maingroup = ggroup(container = mymain, horizontal = T)
  
  leftgroup = ggroup(container = maingroup, horizontal = F)
  
  IDfrm <- gframe("Spectro ID",container=leftgroup, spacing=20)
  IDtext <- gtext("Connecting to spectro. Wait!",width = 150, height=100,container = IDfrm)
  
  gseparator(container=leftgroup)
  
  Setfrm<- gframe("Acquisition parameters", container = leftgroup,horizontal = F, spacing=20)
  glabel("Number of scans", container = Setfrm)
  nscansld <- gspinbutton(1, 100, 1, value=1, container = Setfrm)
  glabel("Integration time (msec)", container = Setfrm)
  intTimesld <- gspinbutton(10,2000,10,value = 10, container = Setfrm)
  
  addSpace(leftgroup,20)
  gseparator(container=leftgroup)
  addSpace(leftgroup,20)
  
  PlotParamfrm <- gframe("Plot parameters", container = leftgroup,horizontal = F, spacing=20)
  autoscaleY <- gcheckbox(text = "Autoscale Y", checked = FALSE, container =PlotParamfrm )
  gridon  <- gcheckbox(text = "Grid on", checked = FALSE, container =PlotParamfrm)
  
  addSpace(leftgroup,20)
  gseparator(container=leftgroup)
  addSpace(leftgroup,20)
  
  Startbtn <- gbutton("START", container = leftgroup, handler=startbtn_handler)
  enabled(Startbtn) <- F
  
  addSpace(leftgroup,20)
  gseparator(container=leftgroup)
  addSpace(leftgroup,20)
  
  Stopbtn <- gbutton("STOP", container = leftgroup, handler = stopbtn_handler)
  enabled(Stopbtn) <- F
  
  ggra = ggraphics(container = maingroup,expand=T)
  
  
  visible(mymain) <- T
  
  
  visible(ggra) <- TRUE
  plot(1:1,1:1)
  plot.new()
  
  source("R/playWith_usb4java.R")
  
  Acquiring <<- FALSE
  
  usbObjects <<- init_usb()
  
  product=0x1022
  vendor=0x2457
  usbDevice <<- find_usb(product,vendor,usbObjects,TRUE)
  cmdList <- get_command_set(product)
  usbDevice <- c(usbDevice, cmdList)
  
  name_serial <- get_OO_name_n_serial(usbObjects, usbDevice)
  dispose(IDtext)
  insert(IDtext," ")
  lapply(name_serial, function(x) insert(IDtext,x,font.attr = list(weight="bold")))
  
  enabled(Startbtn) <- T
  
  wv <<- getWavelengths(usbObjects, usbDevice)
  
  satLevel <<- getMaxSatLevel(usbObjects, usbDevice)
}
