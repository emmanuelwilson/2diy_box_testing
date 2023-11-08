static class HapticBox {
  public PVector topLeft; // m
  public PVector topRight;
  public PVector bottomLeft; // m
  public PVector bottomRight;
  public float L; // m
  public float W; // m
  public float k, mu, maxAL, maxAH;
  private int id;
  static final float vTh = 0.015; // m/s
  private static int nextID = 0;
  boolean onsetFlag = false, offsetFlag = false, active = false;
  
  public HapticBox(float x, float y, float l, float w) {
    topLeft = new PVector(x, y);
    topRight = new PVector(x+w*2,y);  // Double l/w for compatibility with create_box which doubles the l/w for no apparent reason
    bottomRight = new PVector(x+w*2,y+l*2);
    bottomLeft = new PVector(x,y+l*2);
    L = l;  // not doubled since this is used for create_box, which is silly
    W = w;
    k = mu = maxAL = maxAH = 0;
    id = (HapticBox.nextID++);
  }
  
  public int getId() { return id; }
  
  public PVector getTopLeft(){return topLeft;}
  public PVector getTopRight(){return topRight;}
  public PVector getBottomRight(){return bottomRight;}
  public PVector getBottomLeft(){return bottomLeft;}
}
