# Copyright 2021 Nisaba Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Rules for converting Unicode string protos to Pynini TSV format."""

load("@bazel_skylib//rules:build_test.bzl", "build_test")

def _convert_script_data_component(script_data_name, proto_tgts):
    """Converts script data proto into TSV format.

    Args:
      script_data_name: The name of the script data (e.g., `consonant`).
      proto_tgts: Text proto targets make up this component.
    """

    proto_files = " ".join([("$(location %s)" % tgt) for tgt in proto_tgts])
    combined_textproto = "combined_%s.textproto" % script_data_name
    native.genrule(
        name = "combine_%s_textproto" % script_data_name,
        outs = [combined_textproto],
        srcs = proto_tgts,
        visibility = ["//visibility:public"],
        cmd = "cat %s > $@" % proto_files,
    )

    converter_tool = "//nisaba/scripts/utils:unicode_strings_to_tsv"
    converter_rule_name = "generate_" + script_data_name
    native.genrule(
        name = converter_rule_name,
        outs = ["%s.tsv" % script_data_name],
        srcs = [combined_textproto],
        exec_tools = [converter_tool],
        visibility = ["//visibility:public"],
        cmd = "$(location %s) --input_text_proto $(location %s) --output_tsv $@" % (
            converter_tool,
            combined_textproto,
        ),
    )
    build_test(
        name = converter_rule_name + "_smoke_test",
        targets = [":" + converter_rule_name],
    )

def setup_script_data(
        name,
        script_data_components = (),
        more_component_paths = {},
        export_script_data = True):
    """Converts a list of script components to the corresponding TSV files.

    Args:
      name: Name of this macro.
      script_data_components: A list of script data component names.
      more_component_paths: Map of component parts available at a path.
      export_script_data: Whether the script data should be exported. If
        the data is auto-generated set this argument to `False`.
    """

    # Export script data only if it's not auto-generated.
    if export_script_data:
        native.exports_files(
            [
                "%s.textproto" % component
                for component in script_data_components
            ],
        )

    # Creating the map from components to all their text proto targets.
    path_to_components = dict(more_component_paths)
    path_to_components[""] = script_data_components
    component_to_proto_tgts = {}
    for path, components in path_to_components.items():
        for component in components:
            proto_tgt = "%s:%s.textproto" % (path, component)
            component_to_proto_tgts.setdefault(component, []).append(proto_tgt)

    # Adding the build rules for each component.
    for component, proto_tgts in component_to_proto_tgts.items():
        _convert_script_data_component(component, depset(proto_tgts).to_list())
