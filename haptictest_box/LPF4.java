import java.util.ArrayList;
import processing.core.PVector;

public class LPF4 implements Filter {
  private double coeff[] = {  // 4th order 20 Hz cutoff fir1 in Octave
    0.035425, 0.240931, 0.447289, 0.240931, 0.035425
  };
  private ArrayList<PVector> memory;
  public LPF4() {
    memory = new ArrayList<PVector>();
    for (int i = 0; i < coeff.length; i++) {
      memory.add(new PVector(0, 0));
    }
  }
  public PVector push(PVector v) {
    memory.add(0, v);
    return memory.remove(memory.size() - 1);
  }
  public PVector calculate() {
    PVector tmp = new PVector(0, 0);
    for (int i = 0; i < coeff.length; i++) {
      tmp.set(tmp.add(memory.get(i).mult((float)coeff[i])));
    }
    return tmp;
  }
}
