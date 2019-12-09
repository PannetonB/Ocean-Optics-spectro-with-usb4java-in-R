---
output:
  html_document: default
  pdf_document: default
---
# Ocean Optics USB4000 with __*usb4java*__
  
Bernard Panneton  
December 2019  


# Introduction

The usb4java library[^1] is used to communicate with a USB peripheral. It used to interact with an Ocean Optics Inc. USB4000
spectrometers.  

This library was used to build a collection of R functions stored in __*playWith_usbjava.R*__ file. The commands required to 
communicate with the spectrometer are detailed in the device technical manual[^2].  

[^1]: http://usb4java.org/  
[^2]: USB4000-OEM-Data-Sheet.pdf stored in the __Doc__ of the RSTudio project __OceanOptics_with_usb4java_in_R__.  

# Functions in playWith_usb4java.R

## init_usb()  
Initialize usb device:   

1. load required library  
2. init JVM  
3. Set Java class paths  
4. Define some objects  

RETURN: a list of 4 components:  
   
 1. context: a Java object of class org.usb4java.Context  
 2. dlist: a Java object of class org.usb4java.DeviceList  
 3. libusb: a Java object of class org.usb4java.LibUsb  
 4. bufutils: a Java object of class org.usb4java.BufferUtils  

## find_usb <- function(product,vendor,usbObjects, silent=TRUE)  
Given a vendor and a product ID number, find the corresponding
USB device.  

INPUTS:

* product: product ID number  
* vendor: vendor ID number  
* usbObjects: list returned by init_usb
* silent: when TRUE, no output at console.  
  
OUTPUTS: a list with 2 components

1. usbDevice: the device as obtained with dlist$get(as.integer(dev_no))
   where dlist was defined in init_usb
2. usbDescription: obtained by libusb$DeviceDescriptor(usbDevice, usbDescription)  

## get_OO_name_n_serial(usbObjects, usbDevice)  
Function to get device name and version, device serial number and company names.  

INPUTS:  

*usbObjects: the list returned by init_usb()
*usbDevice:  the list returned by find_usb()  

OUTPUTS:  a list with 3 components:  

1. name: name of the USB device
2. version: name of device with version number  
3. serialno: serial number
