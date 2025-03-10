import yaml

def create_yaml_template(fname):
    """
    Args:
        fname (str): file to write template to.
    """
    cam_config = '''intf_map:
  - key:
    - name: ingres_port
      value: 1
      bits: 10
  - action_id:
      bits: 2
      value : 0
  - action_params:
    - name: vrf_id
      value: 0x12345678
      bits: 32
    - name: vlan_id
      value: 0x064
      bits: 12
'''
    with open(fname, 'w', encoding="utf-8") as file:
        file.write(cam_config)

def load_from_yaml(self, fname):
    with open(fname, 'r', encoding="utf-8") as file:
        flow_def_dicts = yaml.safe_load(file)

    for flow_def_key in flow_def_dicts.keys():
        fd = FlowDef(flow_def_dicts[flow_def_key])
        self.add_flow_def(fd)

fname = "./temp.yaml"
create_yaml_template(fname)
load_from_yaml(fname)