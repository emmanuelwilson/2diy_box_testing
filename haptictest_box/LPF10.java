import java.util.ArrayList;
import processing.core.PVector;

public class LPF10 implements Filter {
  private double coeff[] = {  // 10th order 10 Hz cutoff 2 kHz sampling fir1 in Octave
    0.014558, 0.030582, 0.072555, 0.124485, 0.166525, 0.182588, 0.166525, 0.124485, 0.072555, 0.030582, 0.014558
  };
  private ArrayList<PVector> memory;
  public LPF10() {
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
      tmp.add(PVector.mult(memory.get(i), (float)coeff[i]));
    }
    return tmp;
  }
}
