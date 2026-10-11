import json,sys
for f in sys.argv[1:]:
    print("==",f)
    for i,l in enumerate(open(f)):
        try: ev=json.loads(l)
        except: continue
        t=ev.get("type"); par=ev.get("parent_tool_use_id")
        if t=="system" and ev.get("subtype")=="task_notification": print(i,"task_notification",ev.get("status"))
        c=(ev.get("message") or {}).get("content") if isinstance(ev.get("message"),dict) else None
        if not isinstance(c,list): continue
        for b in c:
            if b.get("type")=="tool_use" and not par:
                inp=b["input"]; s=inp.get("file_path") or inp.get("command") or inp.get("subagent_type") or inp.get("skill") or ""
                s=str(s).replace("\n"," ")
                for k in ("/private/var/folders","/var/folders"):
                    pass
                print(i,b["name"],s[:90].split("tmp.")[-1] if "tmp." in s[:90] else s[:90])
