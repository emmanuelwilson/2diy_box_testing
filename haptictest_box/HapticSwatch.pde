static class HapticSwatch {
  public PVector center; // m
  public float radius; // m
  public float k, mu, maxAL, maxAH;
  private int id;
  static final float vTh = 0.015; // m/s
  private static int nextID = 0;
  boolean onsetFlag = false, offsetFlag = false, active = false;
  
  public HapticSwatch(float x, float y, float r) {
    center = new PVector(x, y);
    radius = r;
    k = mu = maxAL = maxAH = 0;
    id = (HapticSwatch.nextID++);
  }
  
  public int getId() { return id; }
}
