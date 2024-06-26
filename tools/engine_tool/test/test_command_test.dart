// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' as convert;
import 'dart:ffi' as ffi show Abi;
import 'dart:io' as io;

import 'package:engine_build_configs/engine_build_configs.dart';
import 'package:engine_repo_tools/engine_repo_tools.dart';
import 'package:engine_tool/src/commands/command_runner.dart';
import 'package:engine_tool/src/environment.dart';
import 'package:litetest/litetest.dart';

import 'fixtures.dart' as fixtures;
import 'utils.dart';

void main() {
  final Engine engine;
  try {
    engine = Engine.findWithin();
  } catch (e) {
    io.stderr.writeln(e);
    io.exitCode = 1;
    return;
  }

  final BuilderConfig linuxTestConfig = BuilderConfig.fromJson(
    path: 'ci/builders/linux_test_config.json',
    map: convert.jsonDecode(fixtures.testConfig('Linux'))
        as Map<String, Object?>,
  );

  final BuilderConfig macTestConfig = BuilderConfig.fromJson(
    path: 'ci/builders/mac_test_config.json',
    map: convert.jsonDecode(fixtures.testConfig('Mac-12'))
        as Map<String, Object?>,
  );

  final BuilderConfig winTestConfig = BuilderConfig.fromJson(
    path: 'ci/builders/win_test_config.json',
    map: convert.jsonDecode(fixtures.testConfig('Windows-11'))
        as Map<String, Object?>,
  );

  final Map<String, BuilderConfig> configs = <String, BuilderConfig>{
    'linux_test_config': linuxTestConfig,
    'linux_test_config2': linuxTestConfig,
    'mac_test_config': macTestConfig,
    'win_test_config': winTestConfig,
  };

  final List<CannedProcess> cannedProcesses = <CannedProcess>[
    CannedProcess((List<String> command) => command.contains('--as=label'),
        stdout: '''
//flutter/display_list:display_list_unittests
//flutter/flow:flow_unittests
//flutter/fml:fml_arc_unittests
'''),
    CannedProcess((List<String> command) => command.contains('--as=output'),
        stdout: '''
display_list_unittests
flow_unittests
fml_arc_unittests
''')
  ];

  test('test command executes test', () async {
    final TestEnvironment testEnvironment = TestEnvironment(engine,
        abi: ffi.Abi.linuxX64, cannedProcesses: cannedProcesses);
    final Environment env = testEnvironment.environment;
    final ToolCommandRunner runner = ToolCommandRunner(
      environment: env,
      configs: configs,
    );
    final int result = await runner.run(<String>[
      'test',
      '//flutter/display_list:display_list_unittests',
    ]);
    expect(result, equals(0));
    expect(testEnvironment.processHistory.length, greaterThan(3));
    final int offset = testEnvironment.processHistory.length - 1;
    expect(testEnvironment.processHistory[offset].command[0],
        endsWith('display_list_unittests'));
  });
}
