
cwlVersion: v1.0

class: Workflow

inputs:
  battenberg:
    type: File
  vcfFile:
    type: File


outputs:
  cnvFile:
    type: File
    outputSource: inputPrep/outputCnvs


steps:
  prep:
    in:
      battenberg: battenberg
    out:
      - cnvFile
    run:
      requirements:
        -
          class: DockerRequirement
          dockerImageId: phylowgs:v1.0-rc2
      class: CommandLineTool
      baseCommand: [python, /opt/phylowgs/parser/parse_cnvs.py, "--cnv-format", battenberg-smchet, "--cnv-output", cnv.file]
      inputs:
        battenberg:
          type: File
          inputBinding:
            position: 2
        cellularity:
          type: float
          default: 1.0
          inputBinding:
            prefix: "--cellularity"
      outputs:
        cnvFile:
          type: File
          outputBinding:
            glob: cnv.file
  inputPrep:
    in:
      cnvs: prep/cnvFile
      vcf_file: vcfFile
    out:
      - outputCnvs
      - outputVariants

    run:
      requirements:
        -
          class: DockerRequirement
          dockerImageId: phylowgs:v1.0-rc2
      class: CommandLineTool
      baseCommand: [python, /opt/phylowgs/parser/create_phylowgs_inputs.py, "--output-cnvs", cnvs.file, "--output-variants", variants.file, "--vcf-type", mutect_smchet]
      inputs:
        subsampleCount:
          type: int?
          inputBinding:
            prefix: "--sample-size"
        only_normal_cn:
          type: boolean
          default: False
          inputBinding:
            prefix: "--only-normal-cn"
        cnvs:
          type: File
          inputBinding:
            prefix: "--cnvs"
        #cnv_confidence:
        #  type: float
        #  default: 1.0
        #  inputBinding:
        #    prefix: "--cnv-confidence"
        #read_length:
        #  type: int
        #  default: 100
        #  inputBinding:
        #    prefix: "--read-length"
        vcf_file:
          type: File
          inputBinding:
            position: 2

      outputs:
        outputCnvs:
          type: File
          outputBinding:
            glob: cnvs.file
        outputVariants:
          type: File
          outputBinding:
            glob: variants.file
