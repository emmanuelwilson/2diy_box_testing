import java.util.ArrayList;
import processing.core.PVector;

public class LPF2 implements Filter {
  private double coeff[] = {  // 20 Hz cutoff 2 kHz sampling 2nd order using fir1 in Octave
    0.068930, 0.862140, 0.068930
  };
  private ArrayList<PVector> memory;
  public LPF2() {
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
