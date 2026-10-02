# Voice reference tuning

Reference: the user-supplied “Bulbasaur Pokédex Entry - Bulbasaur And The Hidden Village” MP3. The recording is not copied into the app or used as playback material.

Local analysis decoded the 15.05-second, 44.1 kHz stereo recording and estimated periodicity using 45 ms autocorrelation windows. The median of high-confidence windows was approximately 167 Hz, with a broad 108–204 Hz interquartile range. These are rough measurements of the mixed recording, not an isolated speaker estimate; music, processing, and octave errors can affect the result. Only 104 windows met the confidence threshold. This analysis does not establish an exact voice match.

The revised synthesis preset raises the previous pitch multiplier from 0.72 to 0.94 and changes the speech rate from 0.43 to 0.47. It adds an optional electronic treatment:

- High-pass at 230 Hz.
- Presence boost of 3 dB at 1.9 kHz.
- Low-pass at 4.8 kHz.
- Radio distortion mixed at 7%, with -6 dB pre-gain.
- A 9 ms doubling delay mixed at 10%, without feedback.
- EQ output reduced by 3 dB for headroom.

The source remains an available US-English system voice. Results vary with the selected voice and require listening on the target device. Settings includes a Bulbasaur preview and an effect toggle for comparison. The build has been validated; a perceptual match has not been established.
