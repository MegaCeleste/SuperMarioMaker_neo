class_name SoundEffectStream
extends RefCounted
## REQ-PHYS-120. Playback flags belong to each actor, not shared media.


static func copy(source: AudioStream, looped: bool = false) -> AudioStream:
	if source == null:
		return null
	var stream: AudioStream = source.duplicate() as AudioStream
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
		if looped:
			wav.loop_begin = 0
			wav.loop_end = roundi(wav.get_length() * float(wav.mix_rate))
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = looped
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = looped
	return stream
