"""Independent integer DF1 oracle and tone stimuli for four-channel RTL."""
import json
import math
from pathlib import Path

FS = 48828.125
ROOT = Path(__file__).resolve().parent.parent
COEFFICIENTS = {}
for mode, low, high in [(1, 150, 6000), (2, 300, 4000), (3, 300, 3400)]:
    rows = []
    for kind, freq, quality in [('hp', low, 1/math.sqrt(2)),
                                ('lp', high, 1/(2*math.cos(math.pi/8))),
                                ('lp', high, 1/(2*math.cos(3*math.pi/8)))]:
        omega = 2*math.pi*freq/FS
        cosine, alpha = math.cos(omega), math.sin(omega)/(2*quality)
        b0 = round(((1+cosine)/2 if kind == 'hp' else (1-cosine)/2)/(1+alpha)*65536)
        rows.append([b0, (-2 if kind == 'hp' else 2)*b0, b0,
                     round(-2*cosine/(1+alpha)*65536), round((1-alpha)/(1+alpha)*65536)])
    COEFFICIENTS[mode] = rows


def generate():
    folder = ROOT/'build/speech_filter_test'
    folder.mkdir(exist_ok=True)
    states = [[[0, 0, 0, 0] for _ in range(3)] for _ in range(4)]
    last_mode = 0
    records, segments = [], []

    def add(mode, values):
        nonlocal last_mode, states
        if mode != last_mode:
            states = [[[0, 0, 0, 0] for _ in range(3)] for _ in range(4)]
        last_mode = mode
        output = []
        for channel, value in enumerate(values):
            value *= 16
            if mode:
                for stage, coef in enumerate(COEFFICIENTS[mode]):
                    x1, x2, y1, y2 = states[channel][stage]
                    acc = coef[0]*value + coef[1]*x1 + coef[2]*x2 - coef[3]*y1 - coef[4]*y2
                    y = max(-134217728, min(134217727, (acc+32768)//65536))
                    states[channel][stage] = [value, x1, y, y1]
                    value = y
            output.append(value//16)
        bits = mode
        for value in values+output:
            bits = (bits << 24) | (value & 0xffffff)
        records.append(f'{bits:049x}')

    for value in [-8388608, -1000000, -1, 0, 1, 1000000, 8388607]:
        add(0, [value, -value if value != -8388608 else 8388607, 12345, -12345])
    for mode in [1, 2, 3]:
        for frequency in [50, 1000, 10000]:
            start = len(records)
            # Clear history between tones by passing through bypass.
            add(0, [0]*4)
            for sample in range(6000):
                values = [round(1000000*math.sin(2*math.pi*frequency*sample/FS+channel*.37)) for channel in range(4)]
                add(mode, values)
            segments.append(dict(mode=mode, frequency=frequency, start=start+1501, end=len(records)))
        add(0, [0]*4)
        for sample in range(4000):
            add(mode, [500000, -500000, 1000000, -1000000])
        segments.append(dict(mode=mode, frequency=0, start=len(records)-500, end=len(records)))
    for sample in range(2000):
        value = 8388607 if (sample//64)%2 else -8388608
        add(1, [value, value, value, value])
    (folder/'vectors.hex').write_text('\n'.join(records)+'\n')
    (folder/'vectors_count.vh').write_text(f'localparam VECTOR_COUNT={len(records)};\n')
    (folder/'segments.json').write_text(json.dumps(segments, indent=2))
    (folder/'coefficients.json').write_text(json.dumps(COEFFICIENTS, indent=2))
    print(f'SPEECH_VECTORS_READY count={len(records)}')


if __name__ == '__main__':
    generate()
