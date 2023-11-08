(
SynthDef("whatever", {|bus = 0, freq = 440, noiseAmt = 0, steady = 0.0, motion = 0.0, gate = 1, atk = 0.01, rel = 1.0, curve = -4, sust = 0.5, bwr = 0.5|
	var env, ton, noi, sig, res;
	env = EnvGen.ar(Env.perc(atk, rel, sust, curve)) + EnvGen.ar(Env.dadsr(atk, atk, 0, 1, rel, curve: curve), gate: gate) * motion;
	ton = SinOsc.ar(freq, mul: (1 - noiseAmt));
	noi = WhiteNoise.ar(noiseAmt * 0.75);
	sig = (ton + noi) * env;
	res = Resonz.ar(sig, freq, bwr);
	Out.ar(bus, [res, res]);
}).add;
)

(
~createListener.free;
~sustainListener.free;
~destroyListener.free;
~synth = Array.newClear(4);

~createListener = OSCFunc.new({|msg, time, addr, recvPort|
	var id, force, pos, mix, freq, steady;
	msg.postln;
	id = msg.at(1).asInteger;
	force = msg.at(2).asFloat; // force
	//pos = msg.at(3).asFloat;
	//mix = msg.at(4).asFloat;
	//freq = msg.at(5).asFloat.midicps;
	//steady = msg.at(6).asFloat;
	// TODO actually map these values properly
	~synth.put(id, Synth("whatever", [
		\motion, force,
		\noiseAmt, 0.4,
		\freq, 220
	]));
}, "/onset", recvPort: 8080);

~sustainListener = OSCFunc({|msg, time, addr, recvPort|
	var id, force, pos;
	msg.postln;
	id = msg.at(1).asInteger;
	force = msg.at(2).asFloat;
	// pos = msg.at(3).asFloat;
	~synth.at(id).set(\motion, force);
}, "/excite", recvPort: 8080);

~destroyListener = OSCFunc({|msg, time, addr, recvPort|
	var id, tmp;
	msg.postln;
	id = msg.at(0).asInteger;
	tmp = ~synth.at(id);
	if(tmp.notNil, {
		tmp.set(\gate, 0);
		fork {
			1.5.wait;
			tmp.free;
		}
	}, {tmp.postln;});
}, "/offset", recvPort: 8080);
)
(
var tmp;
tmp = Synth("whatever", [
	\freq, 440,
	\noiseAmt, 0.6,
	\sust, 0.5
]);
tmp.set(\gate, 0);
fork {
	1.wait;
	tmp.free;
}
)
a.set(\gate, 0);
a.free();
(
a.set(\noiseAmt, 0.75);
)
~synth.at(0)