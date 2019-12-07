package MC;

/*
* To change this license header, choose License Headers in Project Properties.
* To change this template file, choose Tools | Templates
* and open the template in the editor.
*/
import com.sun.jna.Structure;
import java.nio.charset.Charset;
import java.util.Arrays;
import java.util.List;
/**
 *
 * @author riouxma
 */
public class DaqDeviceDescriptor extends Structure {
    public byte[] ProductName = new byte[64];
    public int ProductID;
    public int InterfaceType;
    public byte[] DevString = new byte[64];
    public byte[] UniqueID = new byte[64];
    public long NUID;
    public byte[] Reserved = new byte[512];
    public DaqDeviceDescriptor() {
        super();
    }
    protected List getFieldOrder() {
        return Arrays.asList("ProductName", "ProductID", "InterfaceType", "DevString", "UniqueID", "NUID", "Reserved");
    }
    public DaqDeviceDescriptor(byte ProductName[], int ProductID, int InterfaceType, byte DevString[], byte UniqueID[], long NUID, byte Reserved[]) {
        super();
        if ((ProductName.length != this.ProductName.length))
            throw new IllegalArgumentException("Wrong array size !");
        this.ProductName = ProductName;
        this.ProductID = ProductID;
        this.InterfaceType = InterfaceType;
        if ((DevString.length != this.DevString.length))
            throw new IllegalArgumentException("Wrong array size !");
        this.DevString = DevString;
        if ((UniqueID.length != this.UniqueID.length))
            throw new IllegalArgumentException("Wrong array size !");
        this.UniqueID = UniqueID;
        this.NUID = NUID;
        if ((Reserved.length != this.Reserved.length))
            throw new IllegalArgumentException("Wrong array size !");
        this.Reserved = Reserved;
    }
    public static class ByReference extends DaqDeviceDescriptor implements Structure.ByReference {
        
    };
    public static class ByValue extends DaqDeviceDescriptor implements Structure.ByValue {
        
    };
    public String getID(){
        String UniqueIDS = new String(UniqueID, Charset.forName("UTF-8"));
        return UniqueIDS;
    }
    
}