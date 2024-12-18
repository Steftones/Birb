s.meter;
s.plotTree;
s.boot;
s.options.memSize = 2.pow(20); // most likely needs more memory than the standard
s.reboot;
Server.killAll;
Buffer.freeAll;

(
s = Server.local;

~recordBuffer = Buffer.alloc(s, 44100 * 0.25, 2);
~recordBuffer2 = Buffer.alloc(s, 44100 * 0.1, 2);
~granularEffectsBuffer = Buffer.alloc(s, 44100 * 0.25, 2);
~recordBufChannel = 20;
~granularToneChannel = 30;
~editValue = 0;
~fxSliderValue = 0;

SynthDef(\recordBufferDef, {
	arg out = 0, bufnum = 0, bufnum2 = 0;
	var snd;
	snd = In.ar(~recordBufChannel, 2);
	RecordBuf.ar(snd, bufnum, loop: 1);
	RecordBuf.ar(snd, bufnum2, loop: 1);
}).add;

SynthDef(\recordBufferPlayback, {
	arg out = 0, bufnum = 0, bufnum2 = 0, edit = 0;
	var playbuf, pointer, normBufPlay;
	pointer = Select.ar(
		LFNoise0.kr(1).range(0,2).round(),
		[
			LFNoise2.ar(4).range(0, 22049),
			SinOsc.ar(4).range(0, 22049),
			LFDNoise3.ar(2).range(0, 22049),
		]
	);

	playbuf = Select.ar(
		LFNoise0.kr(1).range(0,1).round(),
		[
			PlayBuf.ar(2, bufnum, LFNoise2.ar(2).range(0.25, 1.5), loop: 1),
			BufRd.ar(2, bufnum, pointer),
		]
	);

	normBufPlay = PlayBuf.ar(2, bufnum, loop: 1);
	playbuf = (playbuf * edit) + (normBufPlay * (1 - edit));
	playbuf = Limiter.ar(playbuf) * -2.dbamp;
	Out.ar(out, playbuf);
}).add;

SynthDef(\shortBird, {
	arg edit = 0, t_trig = 1, out = 0;
	var snd, snd2, pitch, pitch2, lfo;
	var time = 0.15;
	var basePitch = 2157;
	var env = EnvGen.kr(
		Env.new(
			[6, 0, 6],
			[0.1, 0],
			[-3]
		).range(1, 6),
		t_trig,
	);
	var edit1 = edit.linlin(0, 1, 1, 0.2);
	var edit2 = edit.linexp(0, 1, 1, 10);

	pitch = (basePitch * edit1) * env;
	pitch2 = ((basePitch * edit1) * SinOsc.ar(300 * edit2).range(1, 1.5)) * env;

	snd = SinOsc.ar(pitch) ! 2 * -12.dbamp;
	snd = snd + (snd * SinOsc.ar(100).range(0, 1));
	snd2 = SinOsc.ar(pitch2, mul: 0.5)!2 * -12.dbamp;
	snd = (snd + snd2) * EnvGen.kr(Env.perc(0, time, -3), t_trig);
	snd = RLPF.ar(snd, 4500, 0.5);
	Out.ar(out, snd * 1.25.dbamp);
}).add;

SynthDef(\otherBirds, {
	arg envSelect = 0, edit = 0, speed = 1/4, choice = 0, out = 0;
	var snd, lfo, lfo2, pitchEnv, volEnv, pitch;
	var lfos = Select.ar(
		LFDNoise3.kr(40).range(0,2).round(1),
		[
			LFNoise2.ar(1),
			SinOsc.ar(1),
			LFPulse.ar(1/4),
		]
	);

	pitchEnv = Select.ar(
		envSelect,
		[
			Env.new(
				[1, 0, 1, 0, 1, 0, 1, 0, 0],
				[0.1, 0, 0.1, 0, 0.1, 0, 1, 1] * speed,
				[-5]
			).ar().range(1, 1.1),
			SinOsc.ar(40 + edit.linlin(0, 1, 0, 50)).range(1, 1.6),
			Line.ar(2.1, 1, speed/4),
			Env.perc().ar().range(1,1.1),
			Env.new(
				[0, 1, 1, 0, -0.3, 0.2, 0.01, 0, 1] * 4,
				[0.001, 0.25, 0.05, 0.2, 0.2, 0.15, 0] * speed,
				[1, 1, 1, -3, 2, 6]
			).ar().range(1, 1.1),
			Env.new(
				[0, 1, 1, 0, 3, 2, 0.01, 0, 1] * 4,
				[0.001, 0.05, 0.25, 0.2, 0.2, 0.15, 0] * speed,
				[1, 1, 1, -3, 2, 6]
			).ar().range(1, 1.1),
			Saw.ar(16 + edit.linlin(0, 1, 0, 50)).range(1, 1.5)
		]
	);

	lfo2 = Env.triangle.ar(speed)
	.range(edit.linlin(0, 1, 0.9, 0.2), 1.1)
	* SinOsc.ar(1).range(edit.linlin(0, 100, 1, -10),1);

	lfo = SinOsc.ar(11 * lfos.range(1, edit.linlin(0, 1, 1, 5)))
	.range(0.8, edit.linlin(0, 1, 1.2, 5))
	* lfo2;

	pitch = (2357 * lfo) * pitchEnv;
	pitch = Select.kr(
		choice,
		[
			pitch,
			(Line.kr(1000, 4000, 1) * lfo) * pitchEnv,
			(SinOsc.kr(10).range(3000, 1000) * lfo) * pitchEnv,
		]
	);
	snd = SinOsc.ar(pitch) ! 2;
	volEnv = Env.new(
		[0, 0.5, 0.5, 0],
		[0.005, speed, 0.1, 0.1]
	).ar(doneAction: 2);
	snd = snd * volEnv;
	ReplaceOut.ar(out, snd);
}).add;

SynthDef(\woodpecker, {
	arg freq = 440, gate = 1, amp = 0.6, out = 0, edit = 0;
	var formants = [730, 1090, 2440, 3010, 3590];
	var bandwidths = [130, 70, 160, 170, 200];
	var snd = Formant.ar(
		(freq * edit.linexp(0, 1, 1, 100)) * XLine.kr(1, 0.05, 1),
		formants,
		bandwidths,
		0.5
	);
	var env = EnvGen.kr(Env.perc(0.01, edit.linexp(0, 1, 0.2, 0.1)), gate, doneAction: 2);
	snd = snd * env;
	snd = Splay.ar(snd.sum);
	Out.ar(~recordBufChannel, snd * amp);
}).add;

SynthDef(\granularTone, {
	arg trigger = 0, t_trig = 1, lag = 0.01, wetAmount = 1, isNice = 0, makeFx = 0, probability = 0.4;
	var snd = In.ar(~granularToneChannel, 2);
	var dry = In.ar(~granularToneChannel, 2);
	var nice;
	15.do {
		snd = snd + PitchShift.ar(
			snd,
			Rand(0.02, 0.05),
			1 + Amplitude.ar(snd, 0.1, 1),
			1 + Amplitude.ar(snd, 0.1, 1)
		);
	};
	4.do {
		snd = SelectX.ar(Latch.kr(CoinGate.kr(probability, t_trig), t_trig).lag(lag), [
			snd,
			snd + (LPF.ar(GVerb.ar(snd.sum, Rand(30, 50), Rand(1, 3)), 3000) * -10.dbamp)
		]);
		snd = SelectX.ar(Latch.kr(CoinGate.kr(probability, t_trig), t_trig).lag(lag), [
			snd,
			snd + PitchShift.ar(snd, Rand(0.02, 0.05), 1 + Amplitude.ar(snd, 0.01, 0.1))
		]);
		snd = SelectX.ar(Latch.kr(CoinGate.kr(probability, t_trig), t_trig).lag(lag), [
			snd,
			snd + DelayC.ar(snd, 0.2, SinOsc.ar(Rand(0.1, 0.3), [0, pi]).linlin(-1, 1, 0, 1) * 0.001)
		]);
		snd = SelectX.ar(Latch.kr(CoinGate.kr(probability, t_trig), t_trig).lag(lag), [
			snd,
			FreqShift.ar(snd, TRand.ar(-30, 50, t_trig))
		]);
		snd = SelectX.ar(Latch.kr(CoinGate.kr(probability, t_trig), t_trig).lag(lag), [
			snd,
			BPF.ar(snd, LFNoise2.kr(3).linexp(-1, 1, 100, 8000), 0.5)
		]);
	};
	snd = (dry * 3.dbamp) + (snd * (1 - (0.5 * Amplitude.ar(dry, 0.01, 0.1))).clip(0, 1));
	15.do {
		snd = snd + PitchShift.ar(
			snd,
			Rand(0.02, 0.05),
			1 + Amplitude.ar(snd, 0.1, 1),
			1 + Amplitude.ar(snd, 0.1, 1),
			mul: 0.5,
		);
	};
	snd = CombC.ar(snd, 1/2, Rand(0.02, 1/2), 1/2);
	snd = LeakDC.ar(snd);
	snd = HPF.ar(snd, 100);
	4.do {
		snd = SelectX.ar(Latch.kr(CoinGate.kr(probability, t_trig), t_trig).lag(lag), [
			snd,
			snd + CombC.ar(snd, 1/2, rrand(0.002, 1/2), 1/2, mul: 1/4)
		]);
	};
	snd = Limiter.ar(snd) * -5.dbamp;
	snd = LPF.ar(snd, 6000);

	snd = Select.ar(makeFx, [dry, snd]);
	snd = snd + EVerb.ar(SelectX.ar(makeFx, [dry * 1e-09, snd * 0.5]), mix: 0.2, lpf2: 8000);
	nice = EVerb.ar(snd, mix: 1, reverbTime: 6, lpf2: 10000) * -2.dbamp;
	snd = Select.ar(isNice, [snd, nice]);
	ReplaceOut.ar(0, snd * -1.dbamp);
}).add;

~granularEffects = Synth(\granularTone,
	[
		inputBuf: ~granularEffectsBuffer.bufnum,
		endFrames: ~granularEffectsBuffer.numFrames - 1,
		makeFx: 0,
		isNice: 0
	]
);

~rout = Task {
	var choices = Pxrand([0, 0, 1, 2], inf).asStream;
	var birdTypes = Pxrand([0, 0, 0, 1, 2, 3, 4, 6], inf).asStream;

	loop {
		var wait = exprand(1/8, 1);
		rrand(1/4, 1/2).wait;
		if (0.1.coin, {
			var currentBird = [0, 2].choose;
			var currentEnv = birdTypes.next;
			2.do {
				s.bind { g.set(\t_trig, 1); };
				s.bind {
					x = Synth(\otherBirds,
						[
							envSelect: currentEnv,
							speed: wait,
							edit: ~editValue,
							choice: currentBird,
							speed: 1/8,
							out: ~recordBufChannel,
						]
					);
				};
				s.bind { ~drawBird.(~editValue, ~fxSliderValue) };
				rrand(1/6, 1/4).wait;
			};
		}, {
			s.bind { ~granularEffects.set(\t_trig, 1); };
			s.bind {
				x = Synth(\otherBirds,
					[
						envSelect: birdTypes.next,
						speed: wait,
						edit: ~editValue,
						choice: choices.next,
						speed: 1/4,
						out: ~recordBufChannel,
					]
				);
			};
			s.bind { ~drawBird.(~editValue, ~fxSliderValue) };
		});

		(wait + 1/2).wait;

		if (0.4.coin, {
			var waits = rrand(1/8, 1/5);
			rrand(1/2, 1).wait;
			s.bind { ~granularEffects.set(\t_trig, 1); };
			rrand(4, 7).do {
				s.bind {
					x = Synth(\shortBird, [out: ~recordBufChannel, edit: ~editValue ]);
				};
				s.bind { ~drawBird.(~editValue, ~fxSliderValue) };
				waits.wait;
				x.free;
			};
		}, {
			if (0.3.coin, {
				rrand(1/2, 1).wait;
				rrand(5, 16).do {
					s.bind {
						Synth(\woodpecker, [freq: rrand(1, 10), out: 0, edit: ~editValue])
					};
					s.bind { ~drawBird.(~editValue, ~fxSliderValue) };
					(1/16).wait;
				};
				(rrand(1/16, 1/2)).wait;
			});
		});

		(rrand(1/16, 1/2)).wait;
	};
};

~recordSynth = Synth(\recordBufferDef,
	[
		\out, 0,
		\bufnum, ~recordBuffer,
		\bufNum2, ~recordBuffer2,
	]
);
~recordBufferPlaybackSynth = Synth(\recordBufferPlayback,
	[
		\out, ~granularToneChannel,
		\bufnum, ~recordBuffer,
		\bufNum2, ~recordBuffer2,
	]
);

~ui = Dictionary[
	\font -> Dictionary[
		\global -> Font("Hiragino Sans", 12),
		\title -> Font("Hiragino Sans", 110),
		\bird -> Font("Monaco", 3.5, true),
	],
	\color -> Dictionary[
		\background -> Color.fromHexString("#F5F5F5"),
		\slider -> Color.fromHexString("#FFF6F6"),
		\button -> [
			"#E0E0E0",
			"#FFBA49",
			"#99EBE8",
			"#EF5B5B"
		].collect({ |color| Color.fromHexString(color) }),
		\bird -> Color.black,
	],
	\bounds -> Dictionary[
		\window -> Rect(400, 400, 600, 412),
		\title -> Rect(10, 12.5, 300, 100),
		\editSlider -> Rect(20, 130, 200, 50),
		\fxSlider -> Rect(20, 200, 200, 50),
		\bird1 -> Rect(20, 270, 50, 50),
		\bird2 -> Rect(95, 270, 50, 50),
		\woodPecker -> Rect(170, 270, 50, 50),
		\makeNewFxButton -> Rect(20, 340, 50, 50),
		\autoOn -> Rect(95, 340, 50, 50),
		\shh -> Rect(170, 340, 50, 50),
		\ascii -> Rect(220, 10, 400, 400),
	],
];

~granularEffects.set(\wetAmount, 0);

w = Window.new("Birb", ~ui[\bounds][\window])
.front
.background_(~ui[\color][\background])
.alwaysOnTop_(true);

StaticText(w, ~ui[\bounds][\title]).string_("birb.")
.font_(~ui[\font][\title]);

Slider.new(w, ~ui[\bounds][\editSlider])
.font_(~ui[\font][\global])
.background_(~ui[\color][\slider])
.value_(0)
.action_({
	|slider|
	~editValue = slider.value;
});

Slider.new(w, ~ui[\bounds][\fxSlider])
.font_(~ui[\font][\global])
.background_(~ui[\color][\slider])
.value_(0)
.action_({
	|slider|
	~fxSliderValue = slider.value;
	~recordBufferPlaybackSynth.set(\edit, slider.value);
});

~globChoices = Pxrand([0, 0, 1, 2], inf).asStream;
~globTypes = Pxrand([0, 0, 0, 1, 2, 3, 4, 6], inf).asStream;

Button(w, ~ui[\bounds][\bird1])
.font_(~ui[\font][\global])
.states_([
	["1", nil, ~ui[\color][\button][0]],
])
.action_({
	s.bind {
		Synth(\otherBirds, [
			envSelect: ~globTypes.next,
			speed: 1/4,
			edit: ~editValue,
			choice: ~globChoices.next,
			speed: 1/8,
			out: ~recordBufChannel,
		]);
	};
	rrand(2,4).do {
		s.bind { ~drawBird.(~editValue, ~fxSliderValue); };
	};
});

Button(w, ~ui[\bounds][\bird2])
.font_(~ui[\font][\global])
.states_([
	["2", nil, ~ui[\color][\button][0]],
])
.action_({
	fork {
		var waits = rrand(1/8, 1/5);
		rrand(3, 7).do {
			var bird;
			s.bind {
				bird = Synth(\shortBird, [out: ~recordBufChannel, edit: ~editValue ]);
				~drawBird.(~editValue, ~fxSliderValue);
			};
			waits.wait;
			s.bind { bird.free };
		};
	};
});

Button(w, ~ui[\bounds][\woodPecker])
.font_(~ui[\font][\global])
.states_([
	["W", nil, ~ui[\color][\button][0]],
])
.action_({
	fork {
		rrand(5, 16).do {
			s.bind {
				Synth(\woodpecker, [freq: rrand(1, 10), out: 0, edit: ~editValue]);
				~drawBird.(~editValue, ~fxSliderValue);
			};
			(1/16).wait;
		};
	};
});

~returnButtonStates = {
	|text, variable|
	[
		[text, nil, nil],
		[text, nil, variable]
	];
};

Button(w, ~ui[\bounds][\makeNewFxButton])
.font_(~ui[\font][\global])
.states_(~returnButtonStates.("dafuq?", ~ui[\color][\button][1]))
.action_({
	|button|
	s.bind { ~granularEffects.set(\makeFx, button.value); };
});

Button(w, ~ui[\bounds][\autoOn])
.font_(~ui[\font][\global])
.states_(~returnButtonStates.("auto", ~ui[\color][\button][2]))
.action_({
	|button|
	if(button.value === 1, { ~rout.play }, { ~rout.stop });
});

Button(w, ~ui[\bounds][\shh])
.font_(~ui[\font][\global])
.states_(~returnButtonStates.("shhhh", ~ui[\color][\button][3]))
.action_({
	|button|
	s.bind { ~granularEffects.set(\isNice, button.value); };
});


~baseStrings = [
	[1,1,1,1],
	[1,1,2,2],
	[1,2,3,2],
	[1,2,3,4],
];

~drawBird = {
	|edit, fxLevel|
	var editCalc = edit.linlin(0,1,0,3).ceil();
	fork {
		var firstString, secondString, addExtra;
		firstString = " ";
		fxLevel.linexp(0, 1, 43, 10).do {
			firstString = firstString + " "
		};
		secondString = firstString;
		addExtra = 0.5.coin;

		fxLevel.linlin(0, 1, 43, 10).do {
			if(addExtra,
				{ secondString = secondString + " " },
				{ secondString = secondString[0..(secondString.size - 2)] },
			);
		};

		rrand(2,4).do {
			var toPaint = ~birdStrings[~baseStrings[editCalc].choose];
			if ((fxLevel - 0.1).coin, {
				toPaint = [
					toPaint.reverse(),
					toPaint.scramble(),
					toPaint.rotate(rrand(200,1300)),
					toPaint.replace(firstString, secondString),
					// toPaint.replace(firstString, secondString.replace(" ", replace: "-")),
				].wchoose(
					[
						1/8,
						1,
						2,
						2,
						// 2,
					].normalizeSum;
				);
			});
			{ ~asciStuff.string_(toPaint) }.defer;
			rrand(1/24,1/16).wait;
		};
		{ ~asciStuff.string_(~birdStrings[0]) }.defer;
	};
};

// 162 chars
// 160 % contrast
// https://www.asciiart.eu/image-to-ascii
~birdStrings = [
	"

                                                                                           -@@@@@@@@#:        :-+*@@@@@@@
                                                                                       .@@@@@@@@@@@@@@@*.%@@@@@@@@@@@@@@@=
                                                                                     -@@@@+          #@@@@@@#:        @@@
                                                                                   .@@@-               -             :@@
                                                                                  #@@.                              .@@.
                                                                                 %@%                               =@@.
                                                                                *@+              .                =@@
                                                                                @@              +@@              *@@
                                                                                @@               @              =@@
                                                                                @@                             *@@.
                                                                                @@                             @@@
                                                                               .@@                             @@@.
                                                                                @@                             *@@
                                                                                @@                             -@@
                                                                                @@                              @@+
                                                                                @@                              @@@
                                                                               %@@                              -@@
                                                                              #@@=                               @@:
                                                                             %@@#                                @@=
                                                                           -@@@:                                 @@#
                                                                          *@@                                    %@%
                                                                       .@@*                                      %@%
                                                                    +%%#                                         @@*
                                                                 #=@@-                                           @@=
                                                              =%@@#                                             %@@
                                                           %@@@@-                                               @@@
                                                      .@@#@@@#                                                 -@@%
                                                    =%@@@@-                                                   .@@@-
                                                  %@@@@                                                       @@@@
                                               .@@@@*                                                        @@@@
                                             -@@@@-                                                         %@@@
                                           @@@@@.                                                          %@@@.
                                        *@@@@@:                                                           @@@@+
                                    -%@@@@@=                                                            @@@@@.
                                 -@@@@@@=                                                             =@@@@#
                              =@@@@@%                                                               :@@@@@
                            @@@@@@..=*@@.                                                        :@@@@@@:
                           .@@@@@@@@@@@@@                                                =    +@@@@@@#
                            .-=+=-#@@@@:                                 --              @@@@@@@@@-
                                  =@@#%%+--                              @+    =%@@@@@@@@@@@@*
                                     *@@@@@@@@@%#              :-+#@@@@@@@@@@@@@@@@@@@@%- @
                                             .@@%=+%@@@@@@@@@@@@@@@@@@%+=@@               @.
                                              .@@%#%##*=-                @@               %-
                                                                         @@               :@
                                                                         @@                @
                                                                         @@                @
                                                                         @@                #.
                                                                         #@-               :+      .
                                                                         *@-                @    **@=
                                                                         #@:                @  +#@:
                                                                         #@:    :           -=%@@@@#.
                                                                         *@+%@%@@+          %@@@@@@@%+
                                                                         %@@@@.              :%@@
                                                                         %@@%*##+               *@-
                                                                          =@@@-
                                                                             @@@
                                                                              +@@
",
	"
                                                                                                                .+%@-
                                                                                                             %@@@@@@#
                                                                                           -@@@@@@@@#:    %@@@%.  @@
                                                                                       .@@@@@@@@@@@@@@@*@@@-     %@=
                                                                                     -@@@@+          #@@@       %@*
                                                                                   .@@@-                       @@+      :-
                                                                                  #@@.                        @@: -@@@@@@@@@
                                                                                 %@%                         @@@@@@@@@%+=@@@
                                                                                *@+              .          @@@@#:      @@@
                                                                                @@              +@@                   @@@#
                                                                                @@               @                  +@@@
                                                                                @@                                %@@@-
                                                                                @@                              %@@@%
                                                                               .@@                             *@@+
                                                                                @@                             *@@
                                                                                @@                             -@@
                                                                                @@                              @@+
                                                                                @@                              @@@
                                                                               %@@                              -@@
                                                                              #@@=                               @@:
                                                                             %@@#                                @@=
                                                                           -@@@:                                 @@#
                                                                          *@@                                    %@%
                                                                       .@@*                                      %@%
                                                                    +%%#                                         @@*
                                                                 #=@@-                                           @@=
                                                              =%@@#                                             %@@
                                                           %@@@@-                                               @@@
                                                      .@@#@@@#                                                 -@@%
                                                    =%@@@@-                                                   .@@@-
                                                  %@@@@                                                       @@@@
                                               .@@@@*                                                        @@@@
                                             -@@@@-                                                         %@@@
                                           @@@@@.                                                          %@@@.
                                        *@@@@@:                                                           @@@@+
                                    -%@@@@@=                                                            @@@@@.
                                 -@@@@@@=                                                             =@@@@#
                              =@@@@@%                                                               :@@@@@
                            @@@@@@..=*@@.                                                        :@@@@@@:
                           .@@@@@@@@@@@@@                                                =    +@@@@@@#
                            .-=+=-#@@@@:                                 --              @@@@@@@@@-
                                  =@@#%%+--                              @+    =%@@@@@@@@@@@@*
                                     *@@@@@@@@@%#              :-+#@@@@@@@@@@@@@@@@@@@@%- @
                                             .@@%=+%@@@@@@@@@@@@@@@@@@%+=@@               @.
                                              .@@%#%##*=-                @@               %-
                                                                         @@               :@
                                                                         @@                @
                                                                         @@                @
                                                                         @@                #.
                                                                         #@-               :+      .
                                                                         *@-                @    **@=
                                                                         #@:                @  +#@:
                                                                         #@:    :           -=%@@@@#.
                                                                         *@+%@%@@+          %@@@@@@@%+
                                                                         %@@@@.              :%@@
                                                                         %@@%*##+               *@-
                                                                          =@@@-
                                                                             @@@
                                                                              +@@
",
	"
                                                                                                                 -@@@@.
                                                                                                             :@@@%  @@
                                                                                           :**+:-.:-.     #@@%-     @@
                                                                                       +@@@@@@@@@@@@@@#%@@=        @@.
                                                                                     @@@@@@@:          -         @@*
                                                                                   .@@@@*.                     +@#        .=*-
                                                                                  .@@%                       #@@.     +@@@@@@@
                                                                                  @@                       #@@    %@@+:    @@:
                                                                                 *@.             +        :@@%@@@@.      .%@#
                                                                                 @@            -@@         *@@.        @@@@:
                                                                                @@.             %                    #@@%.
                                                                               @@*                                 =@@-
                                                                              .@@                                *@@*
                                                                               @@@                             #@@=
                                                                                @@@=                           @@@@
                                                                                 @@@%                           @@@%
                                                                                 :@@@                            @@@
                                                                                *@@@@                            #@@.
                                                                                @@*                              @@@
                                                                                @-                               %@@
                                                                                                                 -@@*
                                                                                                                  @@@
                                                                         *##@                                      @@@
                                                                      *@%@#                                        %@@
                                                                   .@@@@@                                         :@@=
                                                             +@@@@@@@@@-                                         +@@-
                                                            @@@@@@@@@                                           @@@
                                                          @@@@@@                                               @@@
                                                        #@@@@@@                                               -@@@
                                                       @@@@@@                                                  @@@#
                                                   +@@%@@@%                                                     @@-
                                              :%@@@@@@@:                                                       @@=
                                            #@@@@@:                                                          %@@
                                          .@@@@.                                                           -@@
                                       :#@@@@@                                                            @@%
                                    #@@@@@@+                                                             @@@
                                -@@@@@@@-                                                               @@@-
                             =@@@@@@@=                                                                 .@@@
                          +@@@@@@@@@@*                                                               %@@@@
                           @@@@@@@@@@@@:                                                          +@@@@-
                           -###*=.#@@@@.                                                .-    :%@@@@:
                                 *@@@                                    *              .%.@@@@@%
                                  @@@@@@@@@@@@@@@@:                 -%%%#@-           ..=@
                                    .::..    .#@@@+  #@@@@@@#+-*@@@@@@%%%@%#@@#.         @#
                                               @@@@@@@@@@@@@@@@*+:      +@:              :@
                                                *@@%:                    @%               ::
                                                                         %@
                                                                         %@                 %
                                                                         #@                 @
                                                                         -@:                %       .-
                                                                          %@                @     .@.
                                                                          *@                @-  :@.
                                                                          @@                -% @+
                                                                         @@@  :=%-           @@*#*@@@=
                                                                         @@ =@@.            +@@%
                                                                         %@@@                 +@@%
                                                                         #@@@@@%=+%@            :@@
                                                                         :@@@
                                                                           %@@@.
                                                                             #@@#
",
	"

                                                                                                               :*%@@%@@.
                                                                                                           -#@@@@@@@@@
                                                                                            +*++=*%*-  .-%@@@#:  :@@+
                                                                                         .*@@@@@@@@@@@@@@@#     @@@
                                                                                     .*-*@@          +@-      +@@:           #@@-
                                                                                   -@@@+:                   .@@=        .=%@@@@%
                                                                                  @@*                      =@*        @@@@@@@@:
                                                                                 @@          ..         @@@@-      .#@@@- *@@
                                                                                *@           .%@       @@@*     =@@@@%   +@@
                                                                                @@         %@+=-      @@     @@@@@@-    .@@
                                                                                @@.           .       @@ .@@@@@         %@%
                                                                                -@@@                 @@+@@@+            :@@
                                                                                @@@=                @@@@@.              .@-
                                                                              =@@*                 .@@*            -%*@@@%
                                                                             -@@-                                 %@@
                                                                             @@=                                +@.
                                                                             @@%#*.                            @@
                                                                             #@@@@@@@.                         =@@
                                                                                   .@@.                         %@@@*
                                                                              =+==:*@-                            @@@@@%
                                                                             @@@@@@:                               -@@@@#
                                                                             @#                                       @=*
                                                                           *@@@                                      @%
                                                                    +@#@@@@@@@.                                      @@
                                                                 *#@@@*..                                            @@@@@@.
                                                               =@@@=                                                  .@@@@*
                                              -++:            =@@@*                                                     @@@
                                            *%@@@@@@-      :@@@@@@@                                                    @@@
                                           %@=   -@@@@@@@@@@@@@@@+                                                  @@@@#
                                           @*       #@@@@@@@@@.                                                 *@@@@@*
                                           -@@:                                                              @@@@@@%
                                            -@@@                                                           @@@@@*
                                             @@@@                                                        *@@@@
                                       -*@@@@@@@@*                                                        @@@@@
                                  :@@@@@@@@@@@@@@                                                           @@@@
                                 @@@@@@@@@%#+-                                                               @@@*
                                %@@@@                                                                       :@@@.
                              *@@@#                                                                       -@@@@
                        @@@@@@@@@.                                                                      #@@@@:
                        @@@%-   .%@@@@@.                                                               @@@@-
                         @@@@@@@@@@@@@@@*                                                             *@@@
                           +@@@@*    @@@%                                ..             *         =@@@@@@+
                                     @@@     .             .*#-          @:            +@   .-*@@@@@@@@@
                                      @@@@@@@@@@*        %@@@@@@@@-     *@         - .-@@@@@@@@@@@@#.
                                       =@@@.  +@@     #@@@@@@@%@@@@+--:=@*   :+@@@@**#@@@@@@*.
                                               %@@@@@@@@@@#         -+##@#                +@@%-
                                                 +@@@@@#                 @@*                 @@
                                                                           -@                :@
                                                                           +@                #%
                                                                          @@                *@
                                                                         @*                @@
                                                                        -@                =@
                                                                         @@-               @@@.
                                                                           @@               *@@   =*  .
                                                                            @@              -@@%%@   :
                                                                         %@@@-            .@@@@% ::=
                                                                      =@@@@%  +%%+        @@@@@@@=
                                                                     :@@@%@@@=:. ...     =@@@@@@@%=
                                                                    .@@@ =@@@@#*=.          -#@@@@@:
                                                                       @@+
                                                                         %@:
                                                                          .*#=
",
	"
                                                                                                                      :@%
                                                                                                                    #@@@
                                                                                                                 #@@.@@
                                                                                          *@@@@.             -@@@  #@.
                                                                                        :@@@@@@@%         =@@+   @@=
                                                                                       :@@%   :@@@@@@+  @@@    @@=
                                                                                      -@@       @@@@@@@@%    @@-
                                                                                    -:@@            @@-    %@%         :@@@@@@#
                                                                                .@@@@@@*                 :@@         #@@*   @@@
                                                                                +@@+                    @@+        *@@.     @@*
                                                                              :@@@=         %@ :@@    :@@+       *@@:      @@@
                                                                             @@@@#         +% -@@@    :@@@@.   +@@:      +@@@
                                                                           +@@@%          .@:           =@@  %@@.       @@@:
                                                                         #@@@@                          @@@@@@        =@@*
                                                                       .@@@@                             @@-        .@@@
                                                                        @@-%@+                                   .@@@@
                                                                        #@@@@@                                 %@@@*
                                                                          +@@@@@                             .@@@@@@@@@@:
                                                                           @@@@@@@-                           =@@@@**@@@-
                                                                            @@@@@@@                                   @@=
                                                                             #@@@                                     @@@@@#*@@@@@@@@@@
                                                                             @@                                         *@@@@+.     @@@
                                                                             =@                                                     @@:
                                                                     +        @                                                    @@.
                                                                    @@ @=      =@@#@###                                          .@@
                                                                @@@@@%@@@@         .#@@#                   *#*+-=+=**@@@##%==::-@@-
                                                               @@@@+   @@@@                              @@+%@@@@@@@%*=:.
                                                             :@@       .@@@@*-@@@@@@@@@@*               @.
                                                            :@%          %@@@@@@@@@@@@@@               *@
                                                            @%                                         :@%#+
                                                           %@                                             @@
                                                :#@@@@@@@%#@=                                            -@@
                                             *@@@@@@@@@@@@@*                                             @@%
                                         #@@@@@@@%.       .                                              @@=
                                        @@@@@-                                                          -@@.
                                       %@@@                                                             #@@@@@@+
                                    @@*%@@.                                                              @@@@@@+
                                  .@@@+                                                                    =@@@
                                 .@*                                                                    *@@@@%
                                +                                                                    %@@@@@#
                              =-                                =**:                              #@@@@@%
                             +                        +     *@@@@@@@%                         .@@@@@@%
                                         --#@@@@+     #%@@@@@@@+ @@@@                      @@@@@@@#      .
                                     .-@@@@%@#        =@@@@@.    :@@@                 -   @@@@@@  .##@@@@@=
                     .@@          .+@@.     @@@@:    :@@.         @@@=               +@@+   @@@@@@@@@@@@@@.
                    @@.        +*@@:         *@@@@   =@@.         -@@@@@. *           *@@@@@@@@@@@@@@@-
                  +@@        -@@:              .@@@%@@@@            :@@@@@@@*=.=@@@@@@@@@@@@@+
                 +@+       +@:                   @@@@@@:               -@@@@@@@@@@@@@@*:.:@@#
                 @=:    =@:                        .-                     :@...            @@#
                  +@@@#.                                                  -@                @@
                                                                          #@                #@
                                                                          @@##              @=
                                                                          .@@@:            @#
                                                                          -@@             +@
                                                                         @%               @#
                                                                      @@-                :@@
                                                                       .                 .@@@+      .*#.
                                                                       ..                  %@@@  :*@@@.
                                                                       **                    +@@@@@@
                                                                        @                     @* @@@@
                                                                      - -*@#%*.               @-   %@@
                                                                      :--*@*:                -@   - +@#
                                                                         #=@ :                @@.    #%
                                                                        -@*@#
                                                                    =@@@@-  +
                                                                    @@#@
",
];

~asciStuff = StaticText(w, ~ui[\bounds][\ascii])
.string_(~birdStrings[0])
.font_(~ui[\font][\bird])
.stringColor_(~ui[\color][\bird]);
)
