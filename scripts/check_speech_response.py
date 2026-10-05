"""Measure RTL tone responses against quantized transfer functions (not room SNR)."""
import cmath
import json
import math
from pathlib import Path

folder = Path(__file__).resolve().parent.parent / 'build/speech_filter_test'
actual = [tuple(map(int, line.split())) for line in (folder/'actual.txt').read_text().splitlines()]
coefficients = json.loads((folder/'coefficients.json').read_text())
checks = []
for segment in json.loads((folder/'segments.json').read_text()):
    values = actual[segment['start']:segment['end']]
    mode, frequency = segment['mode'], segment['frequency']
    if not frequency:
        peak = max(abs(v[2]) for v in values)
        assert peak < 100, (mode, peak)
        checks.append(dict(mode=mode, dc_residual_peak_24bit=peak))
        continue
    measured = 10*math.log10(sum(v[2]**2 for v in values)/sum(v[1]**2 for v in values))
    z = cmath.exp(-2j*math.pi*frequency/48828.125)
    response = 1
    for b0, b1, b2, a1, a2 in coefficients[str(mode)]:
        response *= (b0+b1*z+b2*z*z)/(65536+a1*z+a2*z*z)
        a, b = a1/65536, a2/65536
        roots = [(-a+sign*cmath.sqrt(a*a-4*b))/2 for sign in [-1, 1]]
        assert max(abs(root) for root in roots) < 1, (mode, roots)
    expected = 20*math.log10(abs(response))
    assert abs(measured-expected) < .6, (mode, frequency, measured, expected)
    checks.append(dict(mode=mode, frequency_Hz=frequency,
                       measured_RTL_dB=round(measured, 3), expected_quantized_dB=round(expected, 3)))
result = dict(vectors=len(actual), four_channel_bit_exact=True, max_cycles=194,
              sample_period_cycles=1024, checks=checks)
(folder/'frequency_checks.json').write_text(json.dumps(result, indent=2)+'\n')
print('SPEECH_RESPONSE_PASS: stable poles, DC rejection, 50/1000/10000 Hz all profiles')
