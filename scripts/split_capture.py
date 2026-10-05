"""Split raw/processed stereo into mono WAVs without loading the full recording."""
from array import array
import argparse
from pathlib import Path
import sys
import wave


def split(input_file, reuse=False):
    source = Path(input_file).resolve()
    outputs = [source.with_name(source.stem + suffix) for suffix in ('_before.wav', '_after.wav')]
    if any(path.exists() for path in outputs):
        if not reuse or not all(path.exists() for path in outputs):
            raise ValueError('Output before/after file already exists or is incomplete')
        with wave.open(str(source), 'rb') as audio, wave.open(str(outputs[0]), 'rb') as before, wave.open(str(outputs[1]), 'rb') as after:
            if audio.getnchannels() != 2 or audio.getsampwidth() != 2:
                raise ValueError('Expected stereo 16-bit PCM WAV')
            for target in (before, after):
                if (target.getnchannels(), target.getsampwidth(), target.getframerate(), target.getnframes()) != (1, 2, audio.getframerate(), audio.getnframes()):
                    raise ValueError('Existing split audio does not match source')
            while block := audio.readframes(262144):
                samples = array('h')
                samples.frombytes(block)
                for channel, target in enumerate((before, after)):
                    expected = samples[channel::2].tobytes()
                    if target.readframes(len(expected)//2) != expected:
                        raise ValueError('Existing split audio payload does not match source')
        print('Reusing verified before/after files')
        return outputs
    with wave.open(str(source), 'rb') as audio:
        if audio.getnchannels() != 2 or audio.getsampwidth() != 2 or audio.getcomptype() != 'NONE':
            raise ValueError('Expected stereo 16-bit PCM WAV')
        with wave.open(str(outputs[0]), 'wb') as before, wave.open(str(outputs[1]), 'wb') as after:
            for target in (before, after):
                target.setnchannels(1)
                target.setsampwidth(2)
                target.setframerate(audio.getframerate())
                target.setnframes(audio.getnframes())
            while block := audio.readframes(262144):
                samples = array('h')
                samples.frombytes(block)
                if sys.byteorder != 'little':
                    samples.byteswap()
                for channel, target in enumerate((before, after)):
                    mono = samples[channel::2]
                    if sys.byteorder != 'little':
                        mono.byteswap()
                    target.writeframesraw(mono.tobytes())
    for output in outputs:
        print(f'Saved: {output}')
    return outputs


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input')
    parser.add_argument('--reuse', action='store_true')
    args = parser.parse_args()
    split(args.input, args.reuse)
