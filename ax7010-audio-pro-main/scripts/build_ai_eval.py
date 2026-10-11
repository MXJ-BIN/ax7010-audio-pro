"""Build a separate ARM benchmark using the existing, matched Vitis BSP."""
from pathlib import Path
import subprocess
import json
import hashlib
root=Path(__file__).resolve().parent.parent
out=root/'build/ai_eval';out.mkdir(exist_ok=True)
ws=Path(Path('D:/ax7010-audio-pro-vitis/last_workspace.txt').read_text().strip())
bsp=ws/'audio_plat/export/audio_plat/sw/standalone_ps7'
gcc=Path('D:/AMDDesignTools/2026.1/gnu/aarch32/nt/gcc-arm-none-eabi/bin/arm-none-eabi-gcc.exe')
linker=(ws/'doa_uart/src/lscript.ld').read_text()
if 'LENGTH = 0x06f00000' not in linker: raise RuntimeError('DDR recording reservation missing')
linker=linker.replace('_STACK_SIZE : 0x2000','_STACK_SIZE : 0x40000').replace('_HEAP_SIZE : 0x2000','_HEAP_SIZE : 0x100000')
(out/'lscript.ld').write_text(linker)
vendor=root/'third_party/rnnoise'
sources=[vendor/'src'/f'{name}.c' for name in ['denoise','rnn','rnn_data','rnn_reader','pitch','kiss_fft','celt_lpc']]+[root/'sw/ai_eval/main.c']
common=['-O3','-g','-mcpu=cortex-a9','-mfpu=neon','-mfloat-abi=hard','-DSDT','-std=gnu11','-ffunction-sections','-fdata-sections','-fno-math-errno','-Wall','-Wextra','-Wno-unused-parameter','-Wno-sign-compare','-I',str(bsp/'include'),'-I',str((vendor/'include').relative_to(root)),'-I',str((vendor/'src').relative_to(root))]
objects=[]
with (out/'build.log').open('w') as log:
 for source in sources:
  obj=out/(source.stem+'.o');objects.append(obj)
  result=subprocess.run([str(gcc),*common,'-c',str(source.relative_to(root)),'-o',str(obj.relative_to(root))],stdout=log,stderr=subprocess.STDOUT,cwd=root)
  if result.returncode: raise RuntimeError(f'Compile failed: {source}; see {out}/build.log')
 command=[str(gcc),*common,'-specs='+str(bsp/'Xilinx.spec'),*[str(p.relative_to(root)) for p in objects],'-Wl,-T,'+str((out/'lscript.ld').relative_to(root)),'-Wl,--gc-sections','-Wl,-Map,'+str((out/'ai_eval.map').relative_to(root)),'-L'+str(bsp/'lib'),'-Wl,--start-group,-lxilstandalone,-lxiltimer,-lxil,-lgcc,-lc,-lm,--end-group','-o',str((out/'ai_eval.elf').relative_to(root))]
 result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,cwd=root)
 if result.returncode: raise RuntimeError(f'Link failed; see {out}/build.log')
size=subprocess.check_output([str(gcc.parent/'arm-none-eabi-size.exe'),str((out/'ai_eval.elf').relative_to(root))],text=True,cwd=root)
info=dict(upstream_tag='v0.1.1',commit='6cbfd53eb348a8d394e0757b4025c6ded34eb2b6',compiler_flags=common,workspace=str(ws),elf_sha256=hashlib.sha256((out/'ai_eval.elf').read_bytes()).hexdigest(),size=size)
tracked=sources+list((vendor/'src').glob('*.h'))+list((vendor/'include').glob('*.h'))+[Path(__file__).resolve()]
info['source_sha256']={p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in tracked}
(out/'build.json').write_text(json.dumps(info,indent=2))
print(size);print('AI_EVAL_BUILD_PASS')
