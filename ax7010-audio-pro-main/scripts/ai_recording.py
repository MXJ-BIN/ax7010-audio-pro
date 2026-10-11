"""Prepare 48 kHz PCM for PS inference, then validate and export its result."""
import argparse
from fractions import Fraction
import json
import math
from pathlib import Path
import struct
import wave
import zlib
import numpy as np

def resample(values, source_rate):
    ratio=Fraction(48000)/Fraction(str(source_rate))
    count=round(len(values)*ratio)
    if ratio==1: return values.astype(float).copy()
    output=np.empty(count); offsets=np.arange(-31,33)
    cutoff=min(1,float(ratio))*.94
    for start in range(0,count,4096):
        positions=np.arange(start,min(count,start+4096),dtype=np.int64)*ratio.denominator
        centers=positions//ratio.numerator
        fractions=(positions%ratio.numerator)/ratio.numerator
        locations=centers[:,None]+offsets[None,:]
        weights=np.sinc((offsets[None,:]-fractions[:,None])*cutoff)*np.hanning(64)[None,:]
        weights/=weights.sum(axis=1,keepdims=True)
        valid=(locations>=0)&(locations<len(values))
        samples=values[np.clip(locations,0,len(values)-1)]*valid
        output[start:start+len(positions)]=np.sum(samples*weights,axis=1)
    return output

def write_wave(path, values):
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(48000)
        w.writeframes(np.clip(np.rint(values),-32768,32767).astype('<i2').tobytes())

def prepare(args):
    source=Path(args.input);prefix=Path(args.prefix)
    for suffix in ['.input.bin','.request.json','.output.bin','.result.txt','.json','_before.wav','_ai.wav']:
        if Path(str(prefix)+suffix).exists(): raise ValueError('Output already exists: '+str(prefix)+suffix)
    root=Path(__file__).resolve().parent.parent
    build=json.loads((root/'build/ai_eval/build.json').read_text())
    import hashlib
    if hashlib.sha256((root/'build/ai_eval/ai_eval.elf').read_bytes()).hexdigest()!=build['elf_sha256']:
        raise ValueError('AI executable changed; rebuild with scripts/build_ai_eval.py')
    for name,expected in build['source_sha256'].items():
        if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:
            raise ValueError('AI source changed; rebuild with scripts/build_ai_eval.py: '+name)
    prefix.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(source),'rb') as w:
        if w.getsampwidth()!=2 or w.getnchannels() not in (1,2): raise ValueError('16-bit mono/stereo WAV required')
        rate=w.getframerate();channels=w.getnchannels()
        metadata=Path(str(source)+'.json')
        if metadata.exists(): rate=json.loads(metadata.read_text(encoding='utf-8-sig')).get('sample_rate_actual',rate)
        if not math.isfinite(rate) or not 8000<=rate<=192000: raise ValueError('Unsupported source rate')
        count=min(w.getnframes(),int(args.seconds*rate))
        if not count: raise ValueError('Input contains no audio samples')
        a=np.frombuffer(w.readframes(count),dtype='<i2').reshape(-1,channels)
    channel=0 if channels==1 or args.channel=='before' else 1
    x=resample(a[:,channel].astype(float),rate)
    gain=10**(args.gain_db/20); scaled=np.rint(x*gain)
    clipped=int(np.count_nonzero((scaled>32767)|(scaled< -32768)))
    if clipped: raise ValueError(f'Input gain clips {clipped} samples; lower --gain-db')
    frame_count=math.ceil(len(x)/480)+1 # one final zero frame flushes the 480-sample algorithm delay
    pcm=np.zeros(frame_count*480,dtype='<i2');pcm[:len(x)]=scaled.astype('<i2')
    payload=pcm.tobytes();Path(str(prefix)+'.input.bin').write_bytes(payload)
    info=dict(source=str(source.resolve()),channel=args.channel,source_rate_actual=rate,samples_48k=len(x),frames=frame_count,rate=48000,
              input_gain_db=args.gain_db,gain=gain,input_crc32=f'{zlib.crc32(payload):08x}',
              resampler='64-tap Hann-windowed sinc, offline host, exact rational rate; delay centered',
              model='Xiph RNNoise v0.1.1 default model',alignment_removed_samples=480)
    Path(str(prefix)+'.request.json').write_text(json.dumps(info,indent=2)+'\n')
    print(f'AI_INPUT_READY frames={frame_count} source_seconds={len(x)/48000:.3f} gain_db={args.gain_db}')

def finish(args):
    prefix=Path(args.prefix);info=json.loads(Path(str(prefix)+'.request.json').read_text())
    for suffix in ['.json','_before.wav','_ai.wav']:
        if Path(str(prefix)+suffix).exists(): raise ValueError('Output already exists: '+str(prefix)+suffix)
    m=[int(x) for x in Path(str(prefix)+'.result.txt').read_text().split()]
    if len(m)!=32 or m[:3]!=[0x41494556,1,2] or m[3]!=info['frames']: raise ValueError('Invalid board completion metadata')
    raw=Path(str(prefix)+'.output.bin').read_bytes();original=Path(str(prefix)+'.input.bin').read_bytes()
    if len(raw)!=info['frames']*960 or zlib.crc32(raw)!=m[20]: raise ValueError('Output CRC/length mismatch')
    if zlib.crc32(original)!=m[19] or m[19]!=int(info['input_crc32'],16): raise ValueError('Input transfer CRC mismatch')
    data=np.frombuffer(raw,dtype='<i2')[480:480+info['samples_48k']].astype(float)/info['gain']
    baseline=np.frombuffer(original,dtype='<i2')[:info['samples_48k']].astype(float)/info['gain']
    write_wave(str(prefix)+'_before.wav',baseline);write_wave(str(prefix)+'_ai.wav',data)
    total=m[7]+(m[8]<<32)
    info.update(dict(board='AX7010 Cortex-A9',cpu_hz=m[21],first_frame_us=m[6],mean_frame_us=total/m[3],min_frame_us=m[9],max_frame_us=m[10],p95_frame_us=m[11],p99_frame_us=m[12],frames_over_10ms=m[16],nonfinite_values=m[17],state_bytes=m[18],output_crc32=f'{m[20]:08x}',output_clipped_samples=m[25],vad_mean=m[26]/1000,core_time_percent=total/m[3]/10000*100,processing_seconds=total/1e6,
                     measurement_scope='PS input conversion + complete RNNoise + output quantization; excludes host resampling, JTAG transfers and future PL return path',
                     playback='Offline AI output; live headphone path restored to the PL speech-band firmware',
                     quality='No clean reference; output attenuation alone is not SNR or speech quality improvement'))
    Path(str(prefix)+'.json').write_text(json.dumps(info,indent=2)+'\n')
    print(json.dumps(info,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser();commands=parser.add_subparsers(dest='command',required=True)
    p=commands.add_parser('prepare');p.add_argument('--input',required=True);p.add_argument('--prefix',required=True)
    p.add_argument('--channel',choices=['before','after'],default='after');p.add_argument('--seconds',type=float,default=30);p.add_argument('--gain-db',type=float,default=18)
    q=commands.add_parser('finish');q.add_argument('--prefix',required=True)
    args=parser.parse_args()
    if args.command=='prepare':
        if not 0<args.seconds<=120 or not -24<=args.gain_db<=30: parser.error('seconds: (0,120], gain-db: [-24,30]')
        prepare(args)
    else: finish(args)
