/** Haptics simulation */
class SimulationThread implements Runnable {
  float samp = 0;
  boolean leave = false;
  boolean inside = false;
  public void run() {
    renderingForce = true;
    PVector force = new PVector(0, 0);
    lastTime = currTime;
    currTime = System.nanoTime();
    if (haplyBoard.data_available()) {
      widget.device_read_data();
      angles.set(widget.get_device_angles());
      posEE.set(widget.get_device_position(angles.array()));
      posEE.set(device_to_graphics(posEE));
      velEE.set(PVector.mult(PVector.sub(posEE, posEELast),((1000000000f)/(currTime-lastTime))));
      // LPF
      filt.push(velEE.copy());
      velEE.set(filt.calculate());
      
      posEELast.set(posEE);
      
      final float speed = velEE.mag();
      if (speed > maxSpeed) maxSpeed = speed;
      
      // Calculate force
      for (HapticBox s : boxes) {
        //PVector rDiff = posEE.copy().sub(s.center);
        if ((posEE.x >= s.getTopLeft().x) && (posEE.x <= s.getTopRight().x) && (posEE.y >= s.getTopLeft().y) && (posEE.y <= s.getBottomLeft().y)) {
          //print("--------IN BOX--------");
          /*OscMessage msg = new OscMessage("/speed");
          msg.add(velEE.mag() * 1000f);
          oscp5.send(msg, oscDestination);*/
          if (!s.active) {
            s.active = true;
            s.onsetFlag = true;
          }
          // Spring
          //rDiff.setMag(s.radius - rDiff.mag());
          //force.set(force.add(rDiff.mult(s.k)));
          // Friction
          //final float vTh = 0.25; // vibes based, m/s
          //final float vTh = 0.015;
          final float vTh = 0.1;
          final float mass = 0.25; // kg
          final float fnorm = mass * 9.81; // kg * m/s^2 (N)
          final float b = fnorm * s.mu / vTh; // kg / s
          //print(b +"//////////////");
          //print(velEE + "lllllllllllllllllll");
          if (speed < vTh) {
            force.set(force.add(velEE.copy().mult(-b)));
          } else {
            force.set(force.add(velEE.copy().setMag(-s.mu * fnorm)));
          }
          // Texture
          final float maxV = vTh;
          fText.set(velEE.copy().rotate(HALF_PI).setMag(
              min(s.maxAH, speed * s.maxAH / maxV) * sin(textureConst * 150f * samp) +
              min(s.maxAL, speed * s.maxAL / maxV) * sin(textureConst * 25f * samp)
          ));
          force.set(force.add(fText));
          if (inside == false){
            print("   Angles: " + angles + "     ");
            inside = true;
            leave = false;
          }
        } else {
          if (s.active) {
            s.active = false;
            s.offsetFlag = true;
            if (inside ) {
              inside = false;     
              if (leave == false){
                leave = true;
                print("   Angles: " + angles + "     ");
              }
            }
          }
        }
      }
      samp = (samp + 1) % targetRate;
      fEE.set(graphics_to_device(force));
      //TableRow row = log.addRow();
      //row.setFloat("force", currTime-lastTime);
    }
    torques.set(widget.set_device_torques(fEE.array()));
    widget.device_write_torques();
    renderingForce = false;
  }
}
