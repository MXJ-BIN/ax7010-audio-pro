"""Analyze saved PS UART telemetry; sampled observations, not all PL frames."""
import argparse, json, math, re
from pathlib import Path
ROW=re.compile(r"seq=(\d+) valid=(\d+) az=(-?\d+) x_q4=(-?\d+) y_q4=(-?\d+) peak_gate=(\d+)")
def analyze(text,target=None):
    rows=[tuple(map(int,m.groups())) for m in ROW.finditer(text)]
    good=[r for r in rows if r[1] and 0<=r[2]<360]
    result={"observations":len(rows),"valid_observations":len(good),"valid_rate":len(good)/len(rows) if rows else None}
    if good:
        s=sum(math.sin(math.radians(r[2])) for r in good)
        c=sum(math.cos(math.radians(r[2])) for r in good)
        result["circular_mean_deg"]=(math.degrees(math.atan2(s,c))+360)%360 if math.hypot(s,c)>1e-9 else None
    if target is not None and good:
        errors=sorted(abs((r[2]-target+180)%360-180) for r in good)
        result.update(target_deg=target%360,mae_deg=sum(errors)/len(errors),p95_deg=errors[max(0,math.ceil(.95*len(errors))-1)])
    return result
if __name__=="__main__":
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument("log");ap.add_argument("--target",type=float)
    args=ap.parse_args();result=analyze(Path(args.log).read_text(encoding="utf-8",errors="replace"),args.target)
    if not result["observations"]:ap.error("No PS telemetry found in log")
    print(json.dumps(result,indent=2,ensure_ascii=False))
