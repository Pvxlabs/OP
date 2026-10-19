#!/usr/bin/env python3
"""Own-app isolated comparison. CPU time deltas and symbol stacks, never chat bodies."""
from pathlib import Path
import subprocess, time, json, sys, datetime, os
app, destination, mode = sys.argv[1:4]
website = '--website' in sys.argv[4:]
out=Path(destination);out.mkdir(parents=True,exist_ok=True)
def write(name,data): (out/name).write_text(json.dumps(data,indent=2))
def processes():
    raw=subprocess.check_output(['ps','-axo','pid=,time=,rss=,comm='],text=True)
    result={}
    for line in raw.splitlines():
        fields=line.strip().split(maxsplit=3)
        if len(fields)!=4: continue
        pid,cpu,rss,path=fields
        if 'WebKit.WebContent' in path or path.endswith('/OP Embedding Validation'):
            seconds=sum(float(v)*60**i for i,v in enumerate(reversed(cpu.split(':'))))
            result[int(pid)]=(seconds,int(rss),path)
    return result
before=set(processes())
subprocess.run(['open','-n',app,'--env','OP_TEST_CONVERSATION_IDS='+os.environ.get('OP_TEST_CONVERSATION_IDS',''),'--args',str(out),mode]+(['--website'] if website else []),check=True)
end=time.monotonic()+100
while not (out/'ready.json').exists():
    if (out/'results.json').exists(): print((out/'results.json').read_text());sys.exit(2)
    if time.monotonic()>end:write('measurement-status.json',{'status':'BLOCKED','reason':'test host not ready'});sys.exit(2)
    time.sleep(.25)
ready=json.loads((out/'ready.json').read_text());host=ready['pid'];pids=[]
for pid in set(processes())-before:
    label=subprocess.run(['lsappinfo','info','-only','name,bundleid,pid',str(pid)],capture_output=True,text=True).stdout
    if 'OP Embedding Validation Web Content' in label:pids.append(pid)
pids=sorted(pids);write('attribution.json',{'host':host,'webContent':pids,'scope':'new processes, OS label OP Embedding Validation Web Content; all retained test pages, not page-exclusive'})
if not pids:write('measurement-status.json',{'status':'BLOCKED','reason':'no own WebContent process attribution'});sys.exit(2)
tracked=[host]+pids;rows=[];old={};jobs=[]
(out/'go').touch()
for i in range(20):
    now=time.monotonic();utc=datetime.datetime.now(datetime.timezone.utc).isoformat()
    current=processes();row={'utc':utc,'secondsFromGo':i,'processes':[]}
    for pid in tracked:
        if pid not in current:continue
        cpu,rss,_=current[pid];prev=old.get(pid)
        row['processes'].append({'pid':pid,'rssKiB':rss,'intervalCPUPercent':100*(cpu-prev[1])/(now-prev[0]) if prev else None})
        old[pid]=(now,cpu)
    rows.append(row)
    if i==3:
        for pid in tracked:
            jobs.append(subprocess.Popen(['sample',str(pid),'3','-file',str(out/f'sample-{pid}.txt')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL))
    write('resources.json',{'measurement':'per-process CPU time delta / monotonic wall interval; RSS sum may double-count shared mappings; no physical FPS','samples':rows})
    time.sleep(1)
for job in jobs:job.wait(timeout=20)
result=json.loads((out/'results.json').read_text()) if (out/'results.json').exists() else {'status':'BLOCKED','reason':'no completed trajectory'}
(out/'finish').touch()
for _ in range(40):
    if host not in processes():break
    time.sleep(.25)
write('measurement-status.json',{'status':result['status'],'physicalDisplayFPS':'BLOCKED: Animation Hitches preflight failed to finalize','ownWebContentProcesses':len(pids)})
print(json.dumps({'status':result['status'],'output':str(out),'trajectory':result.get('trajectory')}))
