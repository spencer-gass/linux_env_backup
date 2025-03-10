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

def load_from_yaml(fname):
    with open(fname, 'r', encoding="utf-8") as file:
        cam_config_dicts = yaml.safe_load(file)
    return cam_config_dicts

fname = "./temp.yaml"
tname = "intf_map"
create_yaml_template(fname)
config_dict = load_from_yaml(fname)

print(tname in config_dict.keys())