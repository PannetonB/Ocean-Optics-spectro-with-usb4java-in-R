init_cmd <- list(cmd = .jarray(as.raw(1)),
                 outEndPoint =  .jbyte(1),
                 inEndPoint = NULL,
                 inLength = NULL)

queryserial_cmd <- list(cmd = .jarray(as.raw(c(0x05,0x00))),
                        outEndPoint =  .jbyte(1),
                        inEndPoint = .jbyte(0x81),
                        inLength = 20L)

getSpectrum_cmd <- list(cmd = .jarray(as.raw(0x09)),
                        outEndPoint =  .jbyte(1),
                        inEndPoint = list(.jbyte(0x86), .jbyte(0x82), .jbyte(0x82)),
                        inLength = list(4L*512L, 11L*512L, 1L))

wv_cal_0_cmd <- list (cmd = .jarray(as.raw(c(0x05,0x01))),
                      outEndPoint = .jbyte(1),
                      inEndPoint = .jbyte(0x81),
                      inLength = 20L)

wv_cal_1_cmd <- list (cmd = .jarray(as.raw(c(0x05,0x02))),
                      outEndPoint = .jbyte(1),
                      inEndPoint = .jbyte(0x81),
                      inLength = 20L)

wv_cal_2_cmd <- list (cmd = .jarray(as.raw(c(0x05,0x03))),
                      outEndPoint = .jbyte(1),
                      inEndPoint = .jbyte(0x81),
                      inLength = 20L)

wv_cal_3_cmd <- list (cmd = .jarray(as.raw(c(0x05,0x04))),
                      outEndPoint = .jbyte(1),
                      inEndPoint = .jbyte(0x81),
                      inLength = 20L)

maxSatLevel_cmd <- list(cmd = .jarray(as.raw(c(0x6b,0x80))),
                    outEndPoint = .jbyte(1),
                    inEndPoint = .jbyte(0x81),
                    inLength = 3L)


queryStatus_cmd <- list(.jarray(as.raw(0xFE)),
                        outEndPoint = .jbyte(1),
                        inEndPoint = .jbyte(0x81),
                        inLength = 16L)

setIntegrationTime_cmd <- list(cmd =  .jarray(.jbyte(c(0x02, 0x2710))),
                               outEndPoint =  .jbyte(1),
                               inEndPoint = NULL,
                               inLength = NULL)

