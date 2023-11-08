/** OSC Data update thread */
class OscThread implements Runnable {
  void run() {
    OscMessage msg = new OscMessage("/state/endEffector");
    msg.add(velEE.mag());
    msg.add(fEE.mag());
    oscp5.send(msg, oscDestination);
    for (HapticBox s : boxes) {
      //msg = new OscMessage("/state/swatch/" + s.getId());
      if (s.onsetFlag) {
        msg = new OscMessage("/onset");
        msg.add(s.getId());
        msg.add(fEE.mag());
        oscp5.send(msg, oscDestination);
        s.onsetFlag = false;
      }
      if (s.offsetFlag) {
        msg = new OscMessage("/offset");
        msg.add(s.getId());
        oscp5.send(msg, oscDestination);
        s.offsetFlag = false;
      }
      /*if (s.active) {
        msg = new OscMessage("/excite");
        msg.add(s.getId());
        msg.add(fEE.mag());
        oscp5.send(msg, oscDestination);
      }*/
    }
  }
}
