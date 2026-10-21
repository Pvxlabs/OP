#!/usr/bin/env python3
"""Run only isolated integration synthetic tests; sample its entire process family."""
import datetime, json, pathlib, subprocess, time, sys, os, plistlib
root = pathlib.Path(__file__).resolve().parents[1]
app = pathlib.Path(os.environ.get('OP_CEF_TEST_APP', str(root/'build/CEFIntegration/Release/OPCEFIntegration.app'))).resolve()
identity = plistlib.loads((app/'Contents/Info.plist').read_bytes())['CFBundleIdentifier']
installed = pathlib.Path('/Applications/OP.app/Contents/Info.plist')
if installed.exists() and identity == plistlib.loads(installed.read_bytes()).get('CFBundleIdentifier'):
    raise RuntimeError('Synthetic tests require a separately identified app; set OP_CEF_TEST_APP to an isolated review build.')
evidence = root/'build/CEFIntegration/evidence'/('run-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
evidence.mkdir(parents=True)
server = subprocess.Popen(['python3',str(root/'Integration/CEF/fixture.py'),str(evidence)])
process = None
try:
    for _ in range(100):
        if (evidence/'port').exists(): break
        time.sleep(.05)
    origin = 'http://127.0.0.1:'+(evidence/'port').read_text()
    samples=[]
    transport_only = os.environ.get('OP_CEF_TRANSPORT_ONLY') == '1'
    consultation_only = os.environ.get('OP_CEF_CONSULTATION_ONLY') == '1'
    performance_only = os.environ.get('OP_CEF_PERFORMANCE_ONLY') == '1'
    if consultation_only:
        clinx = pathlib.Path(os.environ.get('OP_CLINX_ROOT', str(root.parent/'CLINX'))).resolve()
        sys.path.insert(0,str(clinx))
        from task_registry import TaskRegistry
        registry=TaskRegistry(evidence/'consultation-tasks.sqlite3')
        task=registry.create_task(host='local',workspace_alias='test',project_alias='op-test',project_name='OP bridge fixture',cwd=str(evidence),repository_origin=None,branch=None,title='Synthetic OP consultation')
        (evidence/'consultation-config.json').write_text(json.dumps({'command':[sys.executable,str(clinx/'mcp_server.py'),'--stdio','--consultations-only','--task-db',str(registry.path)],'task_ref':task.task_id}))
    for phase in (['core'] if transport_only or consultation_only or performance_only else ['core','restart']):
        # Fixtures use no account data. Keep Chromium's synthetic cookie key away
        # from the system Keychain and production profiles during ad-hoc signing.
        args = ['open','-n','-W',str(app),'--args','--self-test','--use-mock-keychain','--disable-notifications','--self-test-origin='+origin,'--evidence='+str(evidence)]
        if transport_only: args += ['--transport-check']
        if consultation_only: args += ['--consultation-check']
        if performance_only: args += ['--performance-check']
        if os.environ.get('OP_CEF_HEADER_VISUALS') == '1': args += ['--header-visuals']
        if phase == 'restart': args += ['--restart-check']
        began=time.monotonic(); process=subprocess.Popen(args)
        # Includes real composer guard cases and bounded native shutdown waits.
        while process.poll() is None and time.monotonic()-began < 180:
            rows=[]
            for line in subprocess.check_output(['ps','-axo','pid=,ppid=,%cpu=,rss=,comm='], text=True).splitlines():
                fields=line.strip().split(None,4)
                if len(fields)==5: rows.append(fields)
            main=[int(x[0]) for x in rows if x[4] == str(app/'Contents/MacOS/OPCEFIntegration')]
            family=set(main)
            for _ in range(5): family.update(int(x[0]) for x in rows if int(x[1]) in family)
            parts=[{'pid':int(x[0]),'ppid':int(x[1]),'cpuPS':float(x[2]),'rssMiB':int(x[3])/1024,'role':'renderer' if '(Renderer)' in x[4] else 'gpu' if '(GPU)' in x[4] else 'browser' if int(x[0]) in main else 'utility'} for x in rows if int(x[0]) in family]
            samples.append({'phase':phase,'seconds':round(time.monotonic()-began,3),'processes':parts})
            time.sleep(.25)
        if process.poll() is None: raise RuntimeError('Test timeout; stopping only the isolated review app')
        report=json.loads((evidence/(phase+'.json')).read_text()); print(json.dumps(report,ensure_ascii=False,indent=2),flush=True)
        if report['status'] != 'PASS':
            raise RuntimeError(f"CEF {phase} failed: {report.get('error', 'unknown failure')}; evidence: {evidence}")
    (evidence/'process-samples.json').write_text(json.dumps(samples,indent=2))
    print('Evidence:',evidence)
finally:
    server.terminate();server.wait()
    if process is not None and process.poll() is None:
        # Quit only this separately identified review bundle, including on timeout.
        quit_review = """import AppKit
let target = URL(fileURLWithPath: CommandLine.arguments.last!).standardizedFileURL
for app in NSWorkspace.shared.runningApplications where app.bundleURL?.standardizedFileURL == target {
    _ = app.terminate()
}
"""
        subprocess.run(['xcrun','swift','-',str(app)], input=quit_review, text=True, check=True)
        process.wait(timeout=15)
