# Synthetic diabetes population (deterministic, seed 2026). Writes bundle-*.json (transaction, PUT).
# Based on the FHIR North 2026 demo generator; the random sequence is unchanged, so the measure stays 145 / 29.
import json, random, datetime as dt
random.seed(2026)
N = 1200
CLINICS = [("clinic-1","Lakeside Family Health"),("clinic-2","Northgate Primary Care"),("clinic-3","Riverbend Community Clinic")]
FIRST_F = "Maria Ana Sofia Emma Olivia Chloe Grace Lea Nora Ivy Ruth Alice Mei Priya Fatima Aisha Sarah Julie".split()
FIRST_M = "Joao Liam Noah Lucas Ethan Owen Ravi Omar Daniel Marc Jean Leo Sam Arjun Victor Ben Paul Tom".split()
LAST = "Tremblay Gagnon Roy Cote Bouchard Gauthier Morin Lavoie Fortin Singh Chen Wong Smith Brown Martin Lee Wilson Taylor Nguyen Patel".split()
LOINC="http://loinc.org"; SCT="http://snomed.info/sct"; ICD10="http://hl7.org/fhir/sid/icd-10"; ICD10GM="http://fhir.de/CodeSystem/bfarm/icd-10-gm"
LOCAL="http://clinic-3.example/codes"
CAT="http://terminology.hl7.org/CodeSystem/observation-category"
def d(s): return dt.date.fromisoformat(s)
def rdate(a,b): a,b=d(a),d(b); return a+dt.timedelta(days=random.randint(0,(b-a).days))
def iso(x,h=9): return f"{x.isoformat()}T{h:02d}:{random.choice([0,15,30,45]):02d}:00Z"
res=[]
for cid,name in CLINICS: res.append({"resourceType":"Organization","id":cid,"name":name})
stats={"patients":0,"diabetics":0}
# measure calibration (target CMS122 poor control ~20% overall, ~15-28% per clinic)
A1C_MEAN={"clinic-1":7.15,"clinic-2":7.45,"clinic-3":7.75}
NO_TEST={"clinic-1":5,"clinic-2":7,"clinic-3":9}
def obs(oid,pid,code,disp,when,value,unit,ucode,cat="laboratory",status="final"):
    o={"resourceType":"Observation","id":oid,"status":status,
       "category":[{"coding":[{"system":CAT,"code":cat}]}],
       "code":{"coding":[{"system":LOINC,"code":code,"display":disp}]},
       "subject":{"reference":f"Patient/{pid}"},"effectiveDateTime":iso(when)}
    if value is not None: o["valueQuantity"]={"value":value,"unit":unit,"system":"http://unitsofmeasure.org","code":ucode}
    return o
for i in range(N):
    pid=f"p{i:04d}"; g=random.choice(["female","male"])
    age=random.choices([random.randint(5,17),random.randint(18,65),random.randint(66,90)],[12,63,25])[0]
    birth=dt.date(2026-age,random.randint(1,12),random.randint(1,28))
    cid=random.choices([c[0] for c in CLINICS],[45,35,20])[0]
    p={"resourceType":"Patient","id":pid,"gender":g,"birthDate":birth.isoformat(),
       "name":[{"family":random.choice(LAST),"given":[random.choice(FIRST_F if g=="female" else FIRST_M)]}],
       "address":[{"use":"home","postalCode":f"K{random.randint(1,9)}{random.choice('ABCEGHJ')} {random.randint(1,9)}{random.choice('KLMNPR')}{random.randint(1,9)}"}],
       "managingOrganization":{"reference":f"Organization/{cid}"}}
    res.append(p); stats["patients"]+=1
    # visits in 2026 (most), some only 2025
    nvis=random.choices([0,1,2,3,4],[10,30,30,20,10])[0]
    for k in range(nvis):
        w=rdate("2026-01-05","2026-10-20") if random.random()>0.08 else rdate("2025-03-01","2025-12-20")
        res.append({"resourceType":"Encounter","id":f"{pid}-e{k}","status":"finished",
            "class":{"system":"http://terminology.hl7.org/CodeSystem/v3-ActCode","code":"AMB"},
            "subject":{"reference":f"Patient/{pid}"},"period":{"start":iso(w),"end":iso(w,10)},
            "serviceProvider":{"reference":f"Organization/{cid}"}})
    diab = age>=18 and random.random() < (0.30 if age>=66 else 0.16)
    if not diab:
        if age>=18 and random.random()<0.15:
            res.append(obs(f"{pid}-a1c0",pid,"4548-4","Hemoglobin A1c",rdate("2026-01-10","2026-10-15"),round(random.uniform(4.8,6.2),1),"%","%"))
        continue
    stats["diabetics"]+=1
    style = "local" if cid=="clinic-3" else random.choices(["sct+icd","icdgm"],[70,30])[0]
    coding = {"sct+icd":[{"system":SCT,"code":"44054006","display":"Diabetes mellitus type 2"},{"system":ICD10,"code":"E11.9"}],
              "icdgm":[{"system":ICD10GM,"code":random.choice(["E11.90","E11.91","E11.20"])}],
              "local":[{"system":LOCAL,"code":"DM2","display":"Diabète type 2"}]}[style]
    res.append({"resourceType":"Condition","id":f"{pid}-dm","subject":{"reference":f"Patient/{pid}"},
        "clinicalStatus":{"coding":[{"system":"http://terminology.hl7.org/CodeSystem/condition-clinical","code":"active"}]},
        "verificationStatus":{"coding":[{"system":"http://terminology.hl7.org/CodeSystem/condition-ver-status","code":"confirmed"}]},
        "code":{"coding":coding},"onsetDateTime":iso(rdate("2008-01-01","2025-06-01"))})
    base=random.gauss(A1C_MEAN[cid],1.25); mmol = (cid=="clinic-2" and random.random()<0.5)
    na1c=random.choices([0,1,2,3],[NO_TEST[cid],36,36,18])[0]
    for k in range(na1c):
        when=rdate("2026-01-10","2026-10-15") if random.random()>0.1 else rdate("2025-02-01","2025-12-15")
        v=max(5.2,min(14.5,round(base+random.gauss(0,0.6),1)))
        if mmol: o=obs(f"{pid}-a1c{k}",pid,"4548-4","Hemoglobin A1c",when,round((v-2.15)*10.929),"mmol/mol","mmol/mol")
        else: o=obs(f"{pid}-a1c{k}",pid,"4548-4","Hemoglobin A1c",when,v,"%","%")
        res.append(o)
    # kidney (KED): eGFR + uACR
    if random.random()<0.62:
        w=rdate("2026-01-10","2026-10-15")
        res.append(obs(f"{pid}-egfr",pid,"33914-3","eGFR",w,random.randint(25,105),"mL/min/{1.73_m2}","mL/min/{1.73_m2}"))
        if random.random()<0.7: res.append(obs(f"{pid}-uacr",pid,"9318-7","Albumin/Creatinine [Ratio] in Urine",w,round(random.uniform(0.5,40),1),"mg/mmol","mg/mmol"))
    if random.random()<0.7:
        s=random.randint(118,168); dd=random.randint(70,100); w=rdate("2026-01-10","2026-10-15")
        res.append({"resourceType":"Observation","id":f"{pid}-bp","status":"final","category":[{"coding":[{"system":CAT,"code":"vital-signs"}]}],
          "code":{"coding":[{"system":LOINC,"code":"85354-9","display":"Blood pressure panel"}]},"subject":{"reference":f"Patient/{pid}"},"effectiveDateTime":iso(w),
          "component":[{"code":{"coding":[{"system":LOINC,"code":"8480-6"}]},"valueQuantity":{"value":s,"unit":"mm[Hg]","system":"http://unitsofmeasure.org","code":"mm[Hg]"}},
                       {"code":{"coding":[{"system":LOINC,"code":"8462-4"}]},"valueQuantity":{"value":dd,"unit":"mm[Hg]","system":"http://unitsofmeasure.org","code":"mm[Hg]"}}]})
# data-quality problems (deliberate, for the DQ step)
dq=[r for r in res if r["resourceType"]=="Observation" and r["code"]["coding"][0]["code"]=="4548-4"]
for o in random.sample(dq,9): o.pop("valueQuantity",None); o["id"]=o["id"]  # HbA1c without value
for o in random.sample(dq,3): o["effectiveDateTime"]="1931-05-02T09:00:00Z"   # before birth
for o in random.sample(dq,6): o["valueQuantity"]={"value":o.get("valueQuantity",{}).get("value",8.1),"unit":"percent"}  # no UCUM code
# Maria (the story patient) — keep stable ids from seed.json
res+=[e["resource"] for e in json.load(open("seed.json"))["entry"] if e["resource"]["resourceType"]!="Organization"]

for n in range(0,len(res),400):
    json.dump({"resourceType":"Bundle","type":"transaction","entry":[{"resource":r,"request":{"method":"PUT","url":f"{r['resourceType']}/{r['id']}"}} for r in res[n:n+400]]},open(f"bundle-{n//400:02d}.json","w"))
from collections import Counter
print(stats, Counter(r["resourceType"] for r in res), len(res))

# ---- extra cases, added by hand; no random calls, nobody here enters or leaves the diabetes cohort ----
extra=[]
# Maria: the diagnosis as production data stores it: SNOMED, ICD-10, a local code, a post-coordinated expression
maria=json.loads(json.dumps(next(r for r in res if r["resourceType"]=="Condition" and r["id"]=="p-0101-t2d")))
maria["code"]={"coding":[
    {"system":SCT,"code":"44054006","display":"Diabetes mellitus type 2"},
    {"system":ICD10,"code":"E11.9"},
    {"system":"http://clinic-1.example/codes","code":"DIAB-T2","display":"Diabetes T2 (local)"},
    {"system":SCT,"code":"44054006:246112005=24484000","display":"Diabetes mellitus type 2, severe"}],
  "text":"Type 2 diabetes, severe"}
extra.append(maria)
# Synthea-style social findings recorded as Condition: in OMOP they do not belong to condition_occurrence
adults=[r for r in res if r["resourceType"]=="Patient" and r["id"].startswith("p0") and int(r["birthDate"][:4])<=2008][:40]
for n,p in enumerate(adults):
    for suffix,code,disp in [("emp","160903007","Full-time employment (finding)")]+([("stress","73595000","Stress (finding)")] if n%3==0 else []):
        extra.append({"resourceType":"Condition","id":f"{p['id']}-{suffix}","subject":{"reference":f"Patient/{p['id']}"},
            "clinicalStatus":{"coding":[{"system":"http://terminology.hl7.org/CodeSystem/condition-clinical","code":"active"}]},
            "verificationStatus":{"coding":[{"system":"http://terminology.hl7.org/CodeSystem/condition-ver-status","code":"confirmed"}]},
            "code":{"coding":[{"system":SCT,"code":code,"display":disp}]},"onsetDateTime":"2024-01-15T09:00:00Z"})
# clinic-2 records hypertension with a local code only: nothing to map it with, the record must survive as concept_id = 0
for p in [r for r in adults if r["managingOrganization"]["reference"]=="Organization/clinic-2"][:5]:
    extra.append({"resourceType":"Condition","id":f"{p['id']}-hta","subject":{"reference":f"Patient/{p['id']}"},
        "clinicalStatus":{"coding":[{"system":"http://terminology.hl7.org/CodeSystem/condition-clinical","code":"active"}]},
        "verificationStatus":{"coding":[{"system":"http://terminology.hl7.org/CodeSystem/condition-ver-status","code":"confirmed"}]},
        "code":{"coding":[{"system":"http://clinic-2.example/codes","code":"HTA","display":"Hypertension (local)"}]},"onsetDateTime":"2023-06-01T09:00:00Z"})
json.dump({"resourceType":"Bundle","type":"transaction","entry":[{"resource":r,"request":{"method":"PUT","url":f"{r['resourceType']}/{r['id']}"}} for r in extra]},open("bundle-99-extra.json","w"))
print("extra", len(extra))
