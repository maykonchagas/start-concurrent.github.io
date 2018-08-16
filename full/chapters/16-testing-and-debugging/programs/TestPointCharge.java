import org.junit.*;
import static org.junit.Assert.*;
 
public class TestPointCharge {  
  private PointCharge charge1;
  private PointCharge charge2;
  private PointCharge charge3;
  private PointCharge charge4;
  
  @Before
  public void setUp() {
    charge1 = new PointCharge( 1, 0, 0, 0 );    
    charge2 = new PointCharge( 2, 1, 0, 0 );
    charge3 = new PointCharge( -1, 0, 1, 0 );
    charge4 = new PointCharge( 0, 0, 0, 1 );
  }
  
  @Test
  public void distance() {
    assertEquals( 1.0, charge1.distance(charge2), 0.001 );
    assertEquals( 1.0, charge1.distance(charge3), 0.001 );
    assertEquals( 1.0, charge1.distance(charge4), 0.001 );
    assertEquals( Math.sqrt(2.0), charge2.distance(charge3), 0.001 );
  } 
  
  @Test
  public void scalarForce() {
    assertEquals( 2*PointCharge.K, charge1.scalarForce(charge2), 0.001 );
    assertEquals( -PointCharge.K, charge1.scalarForce(charge3), 0.001 );
    assertEquals( 0.0, charge1.scalarForce(charge4), 0.001 );
    assertEquals( (double)-PointCharge.K, (double)charge2.scalarForce(charge3), 0.001 );
  }   
    
  @Test
  public void fieldMagnitude() {
    assertEquals( 2*PointCharge.K, charge2.fieldMagnitude(0, 0, 0), 0.001 );
    assertEquals( PointCharge.K, charge2.fieldMagnitude(0, 1, 0), 0.001 );
    assertEquals( PointCharge.K, charge2.fieldMagnitude(0, 0, 1), 0.001 );    
  }   
}