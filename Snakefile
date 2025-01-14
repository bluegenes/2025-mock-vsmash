
out_dir = "outputs.2025-mock-smash"
logs_dir = f"{out_dir}/logs"

configfile: "inputs/conf.yml"
PRJ= 'PRJEB74559'
run_type= "test"

sourmash_params = config['sourmash_params'][run_type]
moltypes = sourmash_params.keys()
lgc_thresholds = config["lgc_thresholds"]

# expand files for rule all: (gather files)
# param_combos = []
# for moltype in moltypes:
#     ksizes = sourmash_params[moltype]["ksize"]
#     scaleds = sourmash_params[moltype]["scaled"]
#     combo = expand(f"{moltype}-k{{k}}-sc{{sc}}", k=ksizes, sc=scaleds)
#     param_combos.extend(combo)
# print(param_combos)

"""
build single parameter string for sourmash sketching
"""
def build_param_str(moltype, override_scaled=None):
    ksizes = sourmash_params[moltype]['ksize']
    if override_scaled:
        scaled = override_scaled
    else:
        scaled = min(sourmash_params[moltype]['scaled'])
    k_params = ",".join([f"k={k}" for k in ksizes])
    param_str = f"-p {moltype},{k_params},scaled={scaled},abund"
    return param_str

"""
build multiple params for all sourmash sketching
"""
def build_params(sourmash_params, override_scaled=None):
    param_str = []
    for moltype in sourmash_params.keys():
        param_str.append(build_param_str(moltype, override_scaled))
    return " ".join(param_str)




rule all:
    input: f"{out_dir}/{PRJ}.zip"


rule prj_to_accs:
    output: f"{out_dir}/{PRJ}.urlsketch.csv"
    params:
        bioproject = PRJ,
    log: f"{out_dir}/{PRJ}.prj-to-accs.log"
    benchmark: f"{out_dir}/{PRJ}.prj-to-accs.benchmark"
    shell:
        """
        python prj-to-directsketch.py -p {params.bioproject} -o {output} 2> {log}
        """


rule urlsketch:
    input: 
        f"{out_dir}/{PRJ}.urlsketch.csv"
    output:
        zip=f"{out_dir}/{PRJ}.zip",
        failed=f"{out_dir}/{PRJ}.urlsketch-fail.txt",
    params:
        param_str = lambda w: build_params(sourmash_params),
    log: f"{logs_dir}/urlsketch/{PRJ}.log"
    benchmark: f"{logs_dir}/urlsketch/{PRJ}.benchmark"
    conda: "directsketch"
    shell:
        """
        sourmash scripts urlsketch {input} -n 1 {params.param_str} \
                                   --failed {output.failed} -o {output.zip} 2> {log}
        """