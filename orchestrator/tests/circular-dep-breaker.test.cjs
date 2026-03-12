'use strict';

const { describe, test } = require('node:test');
const assert = require('node:assert/strict');

const {
  analyzeCircularPair,
  generatePatchSpec,
  planBuildOrder,
} = require('../amil/bin/lib/circular-dep-breaker.cjs');

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Build a circularRisk object matching the shape expected by analyzeCircularPair.
 */
function circularRisk(modA, modB, refsAtoB, refsBtoA) {
  return {
    modules: [modA, modB],
    refs_a_to_b: refsAtoB,
    refs_b_to_a: refsBtoA,
  };
}

function m2oRef(fromModule, fromModel, field, toModel) {
  return { from_module: fromModule, from_model: fromModel, field, to_model: toModel, type: 'Many2one' };
}

function o2mRef(fromModule, fromModel, field, toModel) {
  return { from_module: fromModule, from_model: fromModel, field, to_model: toModel, type: 'One2many' };
}

// ─── analyzeCircularPair ─────────────────────────────────────────────────────

describe('analyzeCircularPair', () => {
  test('simple cycle A->B->A: side with more Many2one is primary', () => {
    const risk = circularRisk('hr_core', 'hr_payroll',
      [m2oRef('hr_core', 'hr.employee', 'payroll_id', 'hr.payroll')],    // A->B: 1 M2O
      [o2mRef('hr_payroll', 'hr.payroll', 'employee_ids', 'hr.employee')]  // B->A: 0 M2O
    );

    const result = analyzeCircularPair(risk, {});

    assert.equal(result.primary, 'hr_core');
    assert.equal(result.secondary, 'hr_payroll');
    assert.deepEqual(result.buildOrder, ['hr_core', 'hr_payroll']);
    assert.equal(result.deferredRefs.length, 1);
    assert.equal(result.patchRequired, true);
  });

  test('when B->A has more Many2one, B becomes primary', () => {
    const risk = circularRisk('mod_a', 'mod_b',
      [o2mRef('mod_a', 'a.model', 'b_ids', 'b.model')],              // A->B: 0 M2O
      [m2oRef('mod_b', 'b.model', 'a_id', 'a.model'),
       m2oRef('mod_b', 'b.line', 'a_ref_id', 'a.model')]             // B->A: 2 M2O
    );

    const result = analyzeCircularPair(risk, {});

    assert.equal(result.primary, 'mod_b');
    assert.equal(result.secondary, 'mod_a');
    assert.deepEqual(result.buildOrder, ['mod_b', 'mod_a']);
  });

  test('equal Many2one count: A is primary (first module wins)', () => {
    const risk = circularRisk('mod_x', 'mod_y',
      [m2oRef('mod_x', 'x.model', 'y_id', 'y.model')],
      [m2oRef('mod_y', 'y.model', 'x_id', 'x.model')]
    );

    const result = analyzeCircularPair(risk, {});

    // >= comparison: m2oAtoB(1) >= m2oBtoA(1) -> A is primary
    assert.equal(result.primary, 'mod_x');
    assert.equal(result.secondary, 'mod_y');
  });

  test('no Many2one in either direction: A is primary by default', () => {
    const risk = circularRisk('mod_a', 'mod_b',
      [o2mRef('mod_a', 'a.model', 'b_ids', 'b.model')],
      [o2mRef('mod_b', 'b.model', 'a_ids', 'a.model')]
    );

    const result = analyzeCircularPair(risk, {});

    // Both have 0 M2O, 0 >= 0 is true, so A is primary
    assert.equal(result.primary, 'mod_a');
  });

  test('patchRequired is false when deferredRefs is empty', () => {
    const risk = circularRisk('mod_a', 'mod_b',
      [m2oRef('mod_a', 'a.model', 'b_id', 'b.model')],
      []  // no refs from B to A
    );

    const result = analyzeCircularPair(risk, {});

    assert.equal(result.patchRequired, false);
    assert.deepEqual(result.deferredRefs, []);
  });

  test('handles many2one with lowercase type string', () => {
    const risk = circularRisk('mod_a', 'mod_b',
      [{ from_module: 'mod_a', from_model: 'a.m', field: 'b_id', to_model: 'b.m', type: 'many2one' }],
      [{ from_module: 'mod_b', from_model: 'b.m', field: 'a_id', to_model: 'a.m', type: 'many2one' }]
    );

    const result = analyzeCircularPair(risk, {});

    // Both sides have 1 many2one (lowercase), A wins by >= tie
    assert.equal(result.primary, 'mod_a');
  });
});

// ─── generatePatchSpec ───────────────────────────────────────────────────────

describe('generatePatchSpec', () => {
  test('generates patch with correct module, model, and field info', () => {
    const resolution = {
      primary: 'hr_core',
      secondary: 'hr_payroll',
      buildOrder: ['hr_core', 'hr_payroll'],
      deferredRefs: [
        { from_module: 'hr_payroll', from_model: 'hr.payroll', field: 'employee_ids', to_model: 'hr.employee', type: 'One2many' },
      ],
      patchRequired: true,
    };

    const patch = generatePatchSpec(resolution);

    assert.ok(patch);
    assert.equal(patch.module, 'hr_core');
    assert.equal(patch.patches.length, 1);
    assert.equal(patch.patches[0].module, 'hr_payroll');
    assert.equal(patch.patches[0].model, 'hr.payroll');
    assert.equal(patch.patches[0].field.name, 'employee_ids');
    assert.equal(patch.patches[0].field.type, 'One2many');
    assert.equal(patch.patches[0].field.comodel_name, 'hr.employee');
  });

  test('returns null when patchRequired is false', () => {
    const resolution = {
      primary: 'mod_a',
      secondary: 'mod_b',
      buildOrder: ['mod_a', 'mod_b'],
      deferredRefs: [],
      patchRequired: false,
    };

    const patch = generatePatchSpec(resolution);
    assert.equal(patch, null);
  });

  test('generates multiple patches for multiple deferred refs', () => {
    const resolution = {
      primary: 'mod_a',
      secondary: 'mod_b',
      buildOrder: ['mod_a', 'mod_b'],
      deferredRefs: [
        { from_module: 'mod_b', from_model: 'b.model1', field: 'ref1', to_model: 'a.model1', type: 'Many2one' },
        { from_module: 'mod_b', from_model: 'b.model2', field: 'ref2', to_model: 'a.model2', type: 'One2many' },
      ],
      patchRequired: true,
    };

    const patch = generatePatchSpec(resolution);

    assert.equal(patch.patches.length, 2);
    assert.equal(patch.patches[0].field.name, 'ref1');
    assert.equal(patch.patches[1].field.name, 'ref2');
  });

  test('defaults field type to Many2one when type is missing', () => {
    const resolution = {
      primary: 'mod_a',
      secondary: 'mod_b',
      buildOrder: ['mod_a', 'mod_b'],
      deferredRefs: [
        { from_module: 'mod_b', from_model: 'b.m', field: 'a_id', to_model: 'a.m' },  // no type
      ],
      patchRequired: true,
    };

    const patch = generatePatchSpec(resolution);

    assert.equal(patch.patches[0].field.type, 'Many2one');
  });
});

// ─── planBuildOrder ──────────────────────────────────────────────────────────

describe('planBuildOrder', () => {
  test('no cycles: DAG preserved as-is, empty patchRounds', () => {
    const topoOrder = ['base', 'hr', 'payroll'];

    const result = planBuildOrder(topoOrder, [], {});

    assert.deepEqual(result.order, ['base', 'hr', 'payroll']);
    assert.deepEqual(result.patchRounds, []);
  });

  test('simple cycle: adjusts order so primary comes before secondary', () => {
    // Suppose topo order has payroll before hr, but hr is primary
    const topoOrder = ['base', 'payroll', 'hr'];
    const risks = [
      circularRisk('hr', 'payroll',
        [m2oRef('hr', 'hr.employee', 'payroll_id', 'hr.payroll')],
        [o2mRef('payroll', 'hr.payroll', 'employee_ids', 'hr.employee')]
      ),
    ];

    const result = planBuildOrder(topoOrder, risks, {});

    const idxHr = result.order.indexOf('hr');
    const idxPayroll = result.order.indexOf('payroll');
    assert.ok(idxHr < idxPayroll, 'primary (hr) should come before secondary (payroll)');
    assert.equal(result.patchRounds.length, 1);
  });

  test('primary already before secondary: order unchanged', () => {
    const topoOrder = ['base', 'hr', 'payroll'];
    const risks = [
      circularRisk('hr', 'payroll',
        [m2oRef('hr', 'hr.employee', 'payroll_id', 'hr.payroll')],
        [o2mRef('payroll', 'hr.payroll', 'employee_ids', 'hr.employee')]
      ),
    ];

    const result = planBuildOrder(topoOrder, risks, {});

    assert.deepEqual(result.order, ['base', 'hr', 'payroll']);
  });

  test('complex cycle A->B->C->A: multiple risks produce multiple patches', () => {
    const topoOrder = ['a', 'b', 'c'];
    const risks = [
      circularRisk('a', 'b',
        [m2oRef('a', 'a.m', 'b_id', 'b.m')],
        [o2mRef('b', 'b.m', 'a_ids', 'a.m')]
      ),
      circularRisk('b', 'c',
        [m2oRef('b', 'b.m', 'c_id', 'c.m')],
        [o2mRef('c', 'c.m', 'b_ids', 'b.m')]
      ),
    ];

    const result = planBuildOrder(topoOrder, risks, {});

    assert.equal(result.order.length, 3);
    assert.ok(result.patchRounds.length >= 1);
  });

  test('self-reference style: single module appears in both positions', () => {
    const topoOrder = ['mod_self', 'mod_other'];
    const risks = [
      circularRisk('mod_self', 'mod_self',
        [m2oRef('mod_self', 's.m', 'parent_id', 's.m')],
        [o2mRef('mod_self', 's.m', 'child_ids', 's.m')]
      ),
    ];

    const result = planBuildOrder(topoOrder, risks, {});

    // Should not crash, self-ref means primary == secondary
    assert.ok(result.order.includes('mod_self'));
    assert.ok(result.order.includes('mod_other'));
  });

  test('multiple independent cycles produce independent patches', () => {
    const topoOrder = ['base', 'hr', 'payroll', 'sales', 'inventory'];
    const risks = [
      circularRisk('hr', 'payroll',
        [m2oRef('hr', 'hr.e', 'p_id', 'hr.p')],
        [o2mRef('payroll', 'hr.p', 'e_ids', 'hr.e')]
      ),
      circularRisk('sales', 'inventory',
        [m2oRef('sales', 's.o', 'inv_id', 'i.lot')],
        [o2mRef('inventory', 'i.lot', 'order_ids', 's.o')]
      ),
    ];

    const result = planBuildOrder(topoOrder, risks, {});

    assert.equal(result.patchRounds.length, 2);
    // Both cycles resolved independently
    const patchModules = result.patchRounds.map(p => p.module);
    assert.ok(patchModules.includes('hr'));
    assert.ok(patchModules.includes('sales'));
  });

  test('large DAG with one embedded cycle: only the cycle pair produces a patch', () => {
    const topoOrder = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
    const risks = [
      circularRisk('d', 'e',
        [m2oRef('d', 'd.m', 'e_id', 'e.m')],
        [o2mRef('e', 'e.m', 'd_ids', 'd.m')]
      ),
    ];

    const result = planBuildOrder(topoOrder, risks, {});

    assert.equal(result.order.length, 7);
    assert.equal(result.patchRounds.length, 1);
    assert.equal(result.patchRounds[0].module, 'd');
  });

  test('empty topoOrder with no risks returns empty arrays', () => {
    const result = planBuildOrder([], [], {});

    assert.deepEqual(result.order, []);
    assert.deepEqual(result.patchRounds, []);
  });

  test('deterministic: same input produces same output', () => {
    const topoOrder = ['base', 'payroll', 'hr'];
    const risks = [
      circularRisk('hr', 'payroll',
        [m2oRef('hr', 'hr.e', 'p_id', 'hr.p')],
        [o2mRef('payroll', 'hr.p', 'e_ids', 'hr.e')]
      ),
    ];

    const result1 = planBuildOrder(topoOrder, risks, {});
    const result2 = planBuildOrder(topoOrder, risks, {});

    assert.deepEqual(result1.order, result2.order);
    assert.deepEqual(
      JSON.stringify(result1.patchRounds),
      JSON.stringify(result2.patchRounds)
    );
  });

  test('no patchRound when cycle has no deferred refs', () => {
    const topoOrder = ['mod_a', 'mod_b'];
    const risks = [
      circularRisk('mod_a', 'mod_b',
        [m2oRef('mod_a', 'a.m', 'b_id', 'b.m')],
        []  // no refs from B to A
      ),
    ];

    const result = planBuildOrder(topoOrder, risks, {});

    // patchRequired is false for this resolution, so no patch round
    assert.deepEqual(result.patchRounds, []);
  });
});
