code4 <- "
    int n = length(x);
    SEXP out = PROTECT(allocVector(INTSXP, n/2));
    
    
    for (int i = n; i >= 1; i-=2)
    {
        int dum = RAW(x)[i-1];
        INTEGER(out)[i/2-1] = 256*dum + RAW(x)[i-2];
    }
    UNPROTECT(1);
    
    return out;
"

getLittleEndianIntegerFromByteArray <- cfunction(c(x="raw"), code4)


