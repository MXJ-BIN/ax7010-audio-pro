"""Validate the board CRC and stream raw stereo audio into a WAV file."""
import argparse
import json
from pathlib import Path
import struct
import wave
import zlib


def convert(raw_path, meta_path, output_path):
    raw, meta, output = map(Path, (raw_path, meta_path, output_path))
    if output.exists() or Path(str(output) + '.json').exists():
        raise ValueError('Output WAV or metadata already exists')
    values = [int(line) for line in meta.read_text().splitlines()]
    if len(values) != 16 or values[:3] != [0x41554452, 1, 2]:
        raise ValueError('Recording is not complete and valid')
    frames = values[4]
    if values[3] != 0x08000000 or not 0 < frames <= 100663296:
        raise ValueError('Invalid DDR recording extent')
    if values[13:15] != [1953125, 40] or raw.stat().st_size != frames * 4:
        raise ValueError('Sample rate or raw length mismatch')
    crc = 0
    with raw.open('rb') as source:
        while block := source.read(1048576):
            crc = zlib.crc32(block, crc)
    if crc != values[6]:
        raise ValueError(f'CRC mismatch: board={values[6]:08x} host={crc:08x}')
    with wave.open(str(output), 'wb') as target, raw.open('rb') as source:
        target.setnchannels(2)
        target.setsampwidth(2)
        target.setframerate(48828)
        target.setnframes(frames)
        while block := source.read(1048576):
            target.writeframesraw(block)
    info = dict(sample_rate_actual=1953125/40, frames=frames,
                duration_seconds=frames/(1953125/40), channels=['raw_hp_mic0', 'processed_pre_quarter'],
                crc32=f'{crc:08x}', ctrl=f'{values[7]:08x}', gains=f'{values[8]:08x}',
                options=f'{values[9]:08x}', max_ring_lag_frames=values[10],
                capture_status=f'{values[11]:08x}', export='JTAG DDR',
                note='Channels have processing latency and different gain; not an SNR measurement.')
    Path(str(output) + '.json').write_text(json.dumps(info, indent=2) + '\n', encoding='utf-8')
    print(f'WAV_CRC_PASS frames={frames} duration={info["duration_seconds"]:.3f}s crc={crc:08x}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('raw')
    parser.add_argument('meta')
    parser.add_argument('output')
    args = parser.parse_args()
    convert(args.raw, args.meta, args.output)
