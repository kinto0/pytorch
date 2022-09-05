load("//tools/build_defs:expect.bzl", "expect")
load("//tools/build_defs:fb_xplat_genrule.bzl", "fb_xplat_genrule")
load("//tools/build_defs:type_defs.bzl", "is_list", "is_string")

# @lint-ignore BUCKRESTRICTEDSYNTAX
IS_OSS = read_config("pt", "is_oss", "0") == "1"  # True for OSS BUCK build, and False for internal BUCK build

USED_PT_BACKENDS = [
    "CPU",
    "QuantizedCPU",
    "SparseCPU",  # brings ~20 kb size regression
]

def pt_operator_library(
        name,
        ops = [],
        exported_deps = [],
        check_decl = True,
        train = False,
        model = None,
        include_all_operators = False,
        include_base_operators = True,
        **kwargs):
    (model_name, model_versions, model_assets, model_traced_backends) = validate_and_extract_model_information(
        name,
        model,
    )

    ops = [op.strip() for op in ops]

    # If ops are specified, then we are in static selective build mode, so we append
    # base ops to this list to avoid additional special case logic in subsequent code,
    # unless include_base_operators is explicitly set to False (the default is True)
    if len(ops) > 0 and include_base_operators:
        ops.extend(PT_BASE_OPS)

    labels = kwargs.pop("labels", [])
    visibility = kwargs.pop("visibility", ["PUBLIC"])

    fb_xplat_genrule(
        name = name,
        out = "model_operators.yaml",
        cmd = (
            "$(exe {exe}) " +
            "{optionally_root_ops} " +
            "{optionally_training_root_ops} " +
            "--rule_name {rule_name} " +
            "--output_path \"${{OUT}}\" " +
            "--model_name {model_name} " +
            "--dep_graph_yaml_path {dep_graph_yaml} " +
            "--models_yaml_path {models_yaml} " +
            "{optionally_model_versions} " +
            "{optionally_model_assets} " +
            "{optionally_model_traced_backends} " +
            "{optionally_include_all_operators}"
        ).format(
            exe = "//tools:gen_operators_yaml" if IS_OSS else "fbsource//xplat/caffe2/tools:gen_operators_yaml",
            rule_name = name,
            model_name = model_name,
            dep_graph_yaml = "none" if IS_OSS else "$(location fbsource//xplat/caffe2:pytorch_op_deps)/fb/pytorch_op_deps.yaml ",
            models_yaml = "none" if IS_OSS else "$(location fbsource//xplat/pytorch_models:all_mobile_model_configs)/build/all_mobile_model_configs.yaml ",
            optionally_root_ops = "--root_ops " + (",".join(ops)) if len(ops) > 0 else "",
            optionally_training_root_ops = "--training_root_ops " + (",".join(ops)) if len(ops) > 0 and train else "",
            optionally_model_versions = "--model_versions " + (",".join(model_versions)) if model_versions != None else "",
            optionally_model_assets = "--model_assets " + (",".join(model_assets)) if model_assets != None else "",
            optionally_model_traced_backends = "--model_traced_backends " + (",".join(model_traced_backends)) if model_traced_backends != None else "",
            optionally_include_all_operators = "--include_all_operators " if include_all_operators else "",
        ),
        labels = labels + [
            "pt_operator_library",
            "supermodule:android/default/pytorch",
            "supermodule:ios/default/public.pytorch",
        ] + (["pt_train_operator_library"] if train else []),
        visibility = visibility,
        **kwargs
    )

def validate_and_extract_model_information(name, model):
    model_name = name
    model_versions = None
    model_assets = None
    model_traced_backends = None

    if model != None:
        model_name = model.get("name")
        expect(model_name != None, "Expected Model Name to be present")
        model_versions = model.get("versions")
        expect(is_list(model_versions), "Expected model versions to be a list of string")
        for ver in model_versions or []:
            expect(is_string(ver), "Expected version '{}' to be string".format(str(ver)))
        model_assets = model.get("assets")
        expect(
            model_assets == None or is_list(model_assets),
            "Expected model assets to be a list of string if specified",
        )
        for asset_name in model_assets or []:
            expect(is_string(asset_name), "Expected asset_name '{}' to be string".format(str(asset_name)))
        model_traced_backends = model.get("traced_backends")
        expect(
            model_traced_backends == None or is_list(model_traced_backends),
            "Expected model traced backends to be a list of string if specified",
        )

        if model_traced_backends != None:
            for backend in model_traced_backends:
                expect(is_string(backend), "Expected backend name '{}' to be string".format(str(backend)))
                expect(
                    backend in USED_PT_BACKENDS,
                    "Expected backend name ({}) to be in set: {}".format(backend, ",".join(USED_PT_BACKENDS)),
                )

    return (model_name, model_versions, model_assets, model_traced_backends)

# This file keeps a list of PyTorch operators used by any targets in
# @fbsource//xplat/...
# The purpose of the list is to avoid generating large number of unused
# operator registration code / BUCK rules at build time.
# See more detail at: https://fb.quip.com/ZVh1AgOKW8Vv

PT_OPS_PRIM = [
    "aten::str",
    "aten::list",
    "aten::__range_length",
    "aten::__derive_index",
    "prim::TupleUnpack",
    "prim::unchecked_cast",
    "aten::IntImplicit",
    "aten::FloatImplicit",
    "aten::ScalarImplicit",
    "aten::Bool.Tensor",
    "aten::Bool.int",
    "aten::Bool.float",
    "aten::Int.Tensor",
    "aten::Int.Scalar",
    "aten::Int.int",
    "aten::Int.bool",
    "aten::Int.str",
    "aten::Float.Tensor",
    "aten::Float.Scalar",
    "aten::Float.int",
    "aten::Float.bool",
    "aten::Float.str",
    "aten::format",
    "prim::NumToTensor.Scalar",
    "prim::RaiseException",
    "aten::Size",
    "aten::size",
    "prim::EnumName",
    "prim::EnumValue.int",
    "prim::EnumValue.float",
    "prim::EnumValue.str",
    "prim::TupleIndex",
    "aten::ne.int_list",
    "prim::unchecked_unwrap_optional",
    "prim::device",
    "prim::dtype",
    "aten::__not__",
    "aten::__is__",
    "aten::__isnot__",
    "aten::element_size",
    "aten::numel",
    "aten::dim",
    "aten::get_device",
    "aten::storage_offset",
    "aten::is_contiguous",
    "aten::select.t",
    "aten::__getitem__.t",
    "aten::append.t",
    "aten::reverse.t",
    "aten::extend.t",
    "aten::copy.t",
    "aten::_set_item.t",
    "aten::clear.t",
    "aten::Delete.t",
    "aten::insert.t",
    "aten::pop.t",
    "aten::add.t",
    "aten::add_.t",
    "aten::slice.t",
    "aten::list.t",
    "aten::mul.left_t",
    "aten::mul.right_",
    "aten::mul_.t",
    "aten::len.t",
    "aten::eq.int_list",
    "prim::Uninitialized",
    "prim::Print",
    "aten::eq.enum",
    "aten::ne.enum",
    "aten::dequantize.tensor",
    "aten::dequantize.any",
    "aten::add.str",
    "aten::eq.int",
    "aten::eq.float",
    "aten::eq.int_float",
    "aten::eq.float_int",
    "aten::eq",
    "aten::eq.str",
    "aten::ne.int",
    "aten::ne.float",
    "aten::ne.int_float",
    "aten::ne.float_int",
    "aten::ne",
    "aten::ne.str",
    "aten::lt.int",
    "aten::lt.float",
    "aten::lt.int_float",
    "aten::lt.float_int",
    "aten::lt",
    "aten::lt.str",
    "aten::gt.int",
    "aten::gt.float",
    "aten::gt.int_float",
    "aten::gt.float_int",
    "aten::gt",
    "aten::gt.str",
    "aten::le.int",
    "aten::le.float",
    "aten::le.int_float",
    "aten::le.float_int",
    "aten::le",
    "aten::le.str",
    "aten::ge.int",
    "aten::ge.float",
    "aten::ge.int_float",
    "aten::ge.float_int",
    "aten::ge",
    "aten::ge.str",
    "aten::add.int",
    "aten::add.float",
    "aten::add.int_float",
    "aten::add.float_int",
    "aten::add",
    "aten::sub.int",
    "aten::sub.float",
    "aten::sub.int_float",
    "aten::sub.float_int",
    "aten::sub",
    "aten::mul.int",
    "aten::mul.float",
    "aten::mul.int_float",
    "aten::mul.float_int",
    "aten::mul",
    "aten::__and__.bool",
    "aten::__or__.bool",
    "aten::__xor__.bool",
    "aten::floor.int",
    "aten::floor.float",
    "aten::floor.Scalar",
    "aten::ceil.int",
    "aten::ceil.float",
    "aten::ceil.Scalar",
    "aten::neg.int",
    "aten::neg.float",
    "aten::neg.Scalar",
    "aten::exp.int",
    "aten::exp.float",
    "aten::exp.Scalar",
    "aten::remainder.int",
    "aten::remainder.float",
    "aten::remainder.int_float",
    "aten::remainder.float_int",
    "aten::remainder",
    "aten::div.int",
    "aten::div.float",
    "aten::div",
    "aten::floordiv.int",
    "aten::floordiv.float",
    "aten::floordiv.int_float",
    "aten::floordiv.float_int",
    "aten::floordiv",
    "aten::pow.int",
    "aten::pow.float",
    "aten::pow.int_float",
    "aten::pow.float_int",
    "aten::pow.Scalar_Scalar",
    "aten::pow.int_to_int",
    "prim::min.int",
    "prim::min.float",
    "prim::min.int_float",
    "prim::min.float_int",
    "prim::min",
    "prim::max.int",
    "prim::max.float",
    "prim::max.int_float",
    "prim::max.float_int",
    "prim::max",
    "prim::type",
    "aten::len.Tensor",
    "aten::ord",
    "aten::lower",
    "aten::__contains__.str_list",
    "aten::len.str",
    "aten::__getitem__.str",
    "aten::copy_.Tensor",
    "aten::copy_.int",
    "aten::copy_.float",
    "aten::backward",
    "aten::index.Tensor_hacked_twin",
    "aten::_index_put_impl_.hacked_twin",
    "aten::index_put_.hacked_twin",
    "aten::index_put.hacked_twin",
    "aten::to.prim_Device",
    "aten::to.prim_dtype",
    "prim::is_cuda",
    "prim::data",
    "prim::min.int_list",
    "prim::max.int_list",
    "prim::min.self_int",
    "prim::max.self_int",
    "prim::min.float_list",
    "prim::max.float_list",
    "prim::min.self_float",
    "prim::max.self_float",
    "prim::min.bool_list",
    "prim::max.bool_list",
    "prim::min.self_bool",
    "prim::max.self_bool",
    "aten::len.Dict_str",
    "aten::keys.str",
    "aten::values.str",
    "aten::__getitem__.Dict_str",
    "aten::get.str",
    "aten::get.default_str",
    "aten::setdefault.str",
    "aten::Delete.Dict_str",
    "aten::pop.Dict_str",
    "aten::pop.Dict_default_str",
    "aten::popitem.str",
    "aten::clear.str",
    "aten::update.str",
    "aten::items.str",
    "aten::copy.Dict_str",
    "aten::__contains__.str",
    "aten::_set_item.str",
    "aten::dict.str",
    "aten::len.Dict_int",
    "aten::keys.int",
    "aten::values.int",
    "aten::__getitem__.Dict_int",
    "aten::get.int",
    "aten::get.default_int",
    "aten::setdefault.int",
    "aten::Delete.Dict_int",
    "aten::pop.Dict_int",
    "aten::pop.Dict_default_int",
    "aten::popitem.int",
    "aten::clear.int",
    "aten::update.int",
    "aten::items.int",
    "aten::copy.Dict_int",
    "aten::__contains__.int",
    "aten::_set_item.int",
    "aten::dict.int",
    "aten::len.Dict_bool",
    "aten::keys.bool",
    "aten::values.bool",
    "aten::__getitem__.Dict_bool",
    "aten::get.bool",
    "aten::get.default_bool",
    "aten::setdefault.bool",
    "aten::Delete.Dict_bool",
    "aten::pop.Dict_bool",
    "aten::pop.Dict_default_bool",
    "aten::popitem.bool",
    "aten::clear.bool",
    "aten::update.bool",
    "aten::items.bool",
    "aten::copy.Dict_bool",
    "aten::__contains__.bool",
    "aten::_set_item.bool",
    "aten::dict.bool",
    "aten::len.Dict_float",
    "aten::keys.float",
    "aten::values.float",
    "aten::__getitem__.Dict_float",
    "aten::get.float",
    "aten::get.default_float",
    "aten::setdefault.float",
    "aten::Delete.Dict_float",
    "aten::pop.Dict_float",
    "aten::pop.Dict_default_float",
    "aten::popitem.float",
    "aten::clear.float",
    "aten::update.float",
    "aten::items.float",
    "aten::copy.Dict_float",
    "aten::__contains__.float",
    "aten::_set_item.float",
    "aten::dict.float",
    "aten::len.Dict_Tensor",
    "aten::keys.Tensor",
    "aten::values.Tensor",
    "aten::__getitem__.Dict_Tensor",
    "aten::get.Tensor",
    "aten::get.default_Tensor",
    "aten::setdefault.Tensor",
    "aten::Delete.Dict_Tensor",
    "aten::pop.Dict_Tensor",
    "aten::pop.Dict_default_Tensor",
    "aten::popitem.Tensor",
    "aten::clear.Tensor",
    "aten::update.Tensor",
    "aten::items.Tensor",
    "aten::copy.Dict_Tensor",
    "aten::__contains__.Tensor",
    "aten::_set_item.Tensor",
    "aten::dict.Tensor",
    "aten::__round_to_zero_floordiv.int",
    "aten::mathremainder.int",
    "aten::mathremainder.float",
    "aten::mathremainder.int_float",
    "aten::mathremainder.float_int",
    "aten::mathremainder",
    "aten::__and__.int",
    "aten::__or__.int",
    "aten::__xor__.int",
    "aten::__lshift__.int",
    "aten::__rshift__.int",
    "aten::round.int",
    "aten::round.float",
    "aten::round.Scalar",
    "aten::log.int",
    "aten::log.float",
    "aten::log.Scalar",
    "aten::log.int_int",
    "aten::log.float_float",
    "aten::log.int_float",
    "aten::log.float_int",
    "aten::log.Scalar_Scalar",
    "aten::log1p.int",
    "aten::log1p.float",
    "aten::log1p.Scalar",
    "aten::log10.int",
    "aten::log10.float",
    "aten::log10.Scalar",
    "aten::sqrt.int",
    "aten::sqrt.float",
    "aten::sqrt.Scalar",
    "aten::acos.int",
    "aten::acos.float",
    "aten::acos.Scalar",
    "aten::asin.int",
    "aten::asin.float",
    "aten::asin.Scalar",
    "aten::atan.int",
    "aten::atan.float",
    "aten::atan.Scalar",
    "aten::atan2.int",
    "aten::atan2.float",
    "aten::atan2.int_float",
    "aten::atan2.float_int",
    "aten::atan2.Scalar_Scalar",
    "aten::cos.int",
    "aten::cos.float",
    "aten::cos.Scalar",
    "aten::sin.int",
    "aten::sin.float",
    "aten::sin.Scalar",
    "aten::tan.int",
    "aten::tan.float",
    "aten::tan.Scalar",
    "aten::asinh.int",
    "aten::asinh.float",
    "aten::asinh.Scalar",
    "aten::atanh.int",
    "aten::atanh.float",
    "aten::atanh.Scalar",
    "aten::acosh.int",
    "aten::acosh.float",
    "aten::acosh.Scalar",
    "aten::sinh.int",
    "aten::sinh.float",
    "aten::sinh.Scalar",
    "aten::cosh.int",
    "aten::cosh.float",
    "aten::cosh.Scalar",
    "aten::tanh.int",
    "aten::tanh.float",
    "aten::tanh.Scalar",
    "aten::degrees.int",
    "aten::degrees.float",
    "aten::degrees.Scalar",
    "aten::radians.int",
    "aten::radians.float",
    "aten::radians.Scalar",
    "aten::fmod.int",
    "aten::fmod.float",
    "aten::fmod.int_float",
    "aten::fmod.float_int",
    "aten::fmod",
    "aten::factorial.int",
    "aten::isnan.float",
    "aten::isfinite.float",
    "aten::isinf.float",
    "aten::gamma.int",
    "aten::gamma.float",
    "aten::gamma.Scalar",
    "aten::erf.int",
    "aten::erf.float",
    "aten::erf.Scalar",
    "aten::erfc.int",
    "aten::erfc.float",
    "aten::erfc.Scalar",
    "aten::expm1.int",
    "aten::expm1.float",
    "aten::expm1.Scalar",
    "aten::fabs.int",
    "aten::fabs.float",
    "aten::fabs.Scalar",
    "aten::lgamma.int",
    "aten::lgamma.float",
    "aten::lgamma.Scalar",
    "prim::abs.int",
    "prim::abs.float",
    "prim::abs.Scalar",
    "aten::gcd.int",
    "aten::copysign.int",
    "aten::copysign.float",
    "aten::copysign.int_float",
    "aten::copysign.float_int",
    "aten::copysign",
    "aten::split",
    "aten::tensor.float",
    "aten::as_tensor.float",
    "aten::tensor.int",
    "aten::as_tensor.int",
    "aten::tensor.bool",
    "aten::as_tensor.bool",
    "aten::_infer_size",
    "aten::_no_grad_embedding_renorm_",
    "aten::tensor",
    "aten::as_tensor",
    "aten::as_tensor.list",
    "aten::_pack_sequence",
    "aten::_get_tracing_state",
    "aten::is_scripting",
    "aten::_no_grad_uniform_",
    "aten::_no_grad_normal_",
    "aten::_no_grad_fill_",
    "aten::_no_grad_zero_",
]

PT_BASE_OPS = [
    "aten::_coalesced_",
    "aten::_copy_from",
    "aten::_empty_affine_quantized",
    "aten::_empty_per_channel_affine_quantized",
    "aten::_indices",
    "aten::_nnz",
    "aten::_values",
    "aten::add",
    "aten::add_",
    "aten::arange",
    "aten::as_strided",
    "aten::as_strided_",
    "aten::cat",
    "aten::clone",
    "aten::coalesce",
    "aten::contiguous",
    "aten::copy_",
    "aten::copy_sparse_to_sparse_",
    "aten::dense_dim",
    "aten::dequantize",
    "aten::div",
    "aten::div_",
    "aten::empty",
    "aten::empty_like",
    "aten::empty_strided",
    "aten::eq",
    "aten::equal",
    "aten::expand",
    "aten::fill_",
    "aten::is_coalesced",
    "aten::is_complex",
    "aten::is_floating_point",
    "aten::is_leaf",
    "aten::is_nonzero",
    "aten::item",
    "aten::max",
    "aten::min",
    "aten::mul",
    "aten::mul_",
    "aten::narrow",
    "aten::ne",
    "aten::permute",
    "aten::q_per_channel_axis",
    "aten::q_per_channel_scales",
    "aten::q_per_channel_zero_points",
    "aten::q_scale",
    "aten::q_zero_point",
    "aten::qscheme",
    "aten::quantize_per_tensor",
    "aten::reshape",
    "aten::_reshape_alias",
    "aten::resize_",
    "aten::resize_as_",
    "aten::scalar_tensor",
    "aten::select",
    "aten::set_",
    "aten::size",
    "aten::slice",
    "aten::sparse_dim",
    "aten::sparse_resize_and_clear_",
    "aten::squeeze",
    "aten::squeeze_",
    "aten::stride",
    "aten::sub",
    "aten::sub_",
    "aten::sum",
    "aten::t",
    "aten::to",
    "aten::_to_copy",
    "aten::unsqueeze",
    "aten::view",
    "aten::zero_",
    "aten::zeros",
    "aten::zeros_like",
]
