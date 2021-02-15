/**
 * High-level idea:
 *  Given the initial architecture A, the dataflow D, the initial compromised
 *  component c_init, the attack capability k (steps), this model computes:
 *    1. all the potentially compromised components C_comp such that for any
 *    component c \in C_comp, the distance dist(c, c_init) <= k;
 *    2. generate a degraded system architecture A' which maximizes the available
 *    system functionalities, i.e., for any function F, let C_F be the set of
 *    components associated with F, for any component c \in C_F, we have 
 *      1. there exists a producer component p in the dataflow D from which c can consume
 *      data through a path p;
 *      2. there eixsts a path p' in the degraded C&C view (which contains network
 *      devices) such that it covers the dataflow path p;
 *      3. for any component c' in the path p', c' should not be compromised
 * Maximization goal:
 *  1. Minimize the connection differences between the initial architecture and
 *  the degraded one;
 *  2. A function is satisfied when all its associated components can successfully
 *  consume data. Then, we try to maximize the number of satisfied functions
 *  under attacks.
 */

/*************************************
 * Component definitions
 ************************************/
abstract sig Component {
  // Initial architecture of the system, this is used to find the set of
  // compromised components
  initConn: set Component,
  // Generated architecture, this is the architecture after degradation
  degradedConn: set Component,

  // Data consumed and produced by this component
  consume: set Data,
  produce: set Data,
  // The set of components that the data can flow to from this component
  dataflow: set Component,

  // The path for this component to consume a data in the dataflow graph
  dataflowPath: Data -> Component -> Component,
  // The path for this component to consume a data in the C&C graph (degraded)
  dataCCPath: Data -> Component -> Component
}

sig Compromised in Component {}

// Network devices
abstract sig NetworkDevice extends Component {}

abstract sig Firewall extends NetworkDevice {}
one sig DMZFirewall1 extends Firewall {}
one sig DMZFirewall2 extends Firewall {}
sig BackupFirewall extends Firewall {}

abstract sig Switch extends NetworkDevice {}
one sig Switch1 extends Switch {}
one sig Switch2 extends Switch {}
one sig Switch3 extends Switch {}
one sig Switch4 extends Switch {}
sig BackupSwitch extends Switch {}

// Functional devices
abstract sig FunctionDevice extends Component {}

abstract sig Printer extends FunctionDevice {}
one sig Printer1 extends Printer {}
sig BackupPrinter extends Printer {}

one sig VPN extends FunctionDevice {}

one sig Internet extends FunctionDevice {}

abstract sig SCADA extends FunctionDevice {}
one sig SCADA1 extends SCADA {}
one sig SCADA2 extends SCADA {}
sig BackupSCADA extends SCADA {}

abstract sig OPC extends FunctionDevice {}
one sig OPC1 extends OPC {}
one sig OPC2 extends OPC {}
sig BackupOPC extends OPC {}

abstract sig HMI extends FunctionDevice {}
one sig HMI1 extends HMI {}
one sig HMI2 extends HMI {}
sig BackupHMI extends HMI {}

abstract sig EngWorkstation extends FunctionDevice {}
one sig EngWorkstation1 extends EngWorkstation {}
one sig EngWorkstation2 extends EngWorkstation {}
sig BackupEngWorkstation extends EngWorkstation {}

abstract sig Historian extends FunctionDevice {}
one sig Historian1 extends Historian {}
one sig Historian2 extends Historian {}
sig BackupHistorian extends Historian {}

abstract sig NTP extends FunctionDevice {}
one sig NTP1 extends NTP {}
one sig NTP2 extends NTP {}
sig BackupNTP extends NTP {}

abstract sig RTU extends FunctionDevice {}
one sig RTU1 extends RTU {}
one sig RTU2 extends RTU {}
sig BackupRTU extends RTU {}

abstract sig Relay extends FunctionDevice {}
one sig Relay1 extends Relay {}
one sig Relay2 extends Relay {}
sig BackupRelay extends Relay {}

/*************************************
 * Architecture constraints
 ************************************/
// If A is connected to B, then B is also connected to A
pred biconnected[conn: Component -> Component] {
  all disj c1, c2: Component | c1 -> c2 in conn implies c2 -> c1 in conn
}

// No self-loop in connections
pred noSelfLoop[conn: Component -> Component] {
  all c: Component | c -> c not in conn
}

// Functional components (e.g., printers, SCADA) should be connected through swithers.
pred archStyle[conn: Component -> Component] {
  all c: FunctionDevice | lone c.conn and shouldConnectTo[c, Switch, conn]
}

pred validArch[conn: Component -> Component] {
  biconnected[conn]
  noSelfLoop[conn]
  archStyle[conn]
}

// Initial architecture
fact {
  initConn =
    OPC1 -> Switch1 + Switch1 -> OPC1 +
    HMI1 -> Switch1 + Switch1 -> HMI1 +
    SCADA1 -> Switch1 + Switch1 -> SCADA1 +
    EngWorkstation1 -> Switch1 + Switch1 -> EngWorkstation1 +
    NTP1 -> Switch1 + Switch1 -> NTP1 +
    Historian1 -> Switch1 + Switch1 -> Historian1 +

    Switch1 -> DMZFirewall1 + DMZFirewall1 -> Switch1 +
    DMZFirewall1 -> Switch2 + Switch2 -> DMZFirewall1 +

    Switch2 -> Printer1 + Printer1 -> Switch2 +
    Switch2 -> VPN + VPN -> Switch2 +
    Switch2 -> Internet + Internet -> Switch2 +

    Switch3 -> DMZFirewall1 + DMZFirewall1 -> Switch3 +
    OPC2 -> Switch3 + Switch3 -> OPC2 +
    HMI2 -> Switch3 + Switch3 -> HMI2 +
    SCADA2 -> Switch3 + Switch3 -> SCADA2 +
    EngWorkstation2 -> Switch3 + Switch3 -> EngWorkstation2 +
    Historian2 -> Switch3 + Switch3 -> Historian2 +
    NTP2 -> Switch3 + Switch3 -> NTP2 +

    Switch1 -> DMZFirewall2 + DMZFirewall2 -> Switch1 +
    DMZFirewall2 -> Switch4 + Switch4 -> DMZFirewall2 +
    RTU1 -> Switch4 + Switch4 -> RTU1 +
    RTU2 -> Switch4 + Switch4 -> RTU2 +
    Relay1 -> Switch4 + Switch4 -> Relay1 +
    Relay2 -> Switch4 + Switch4 -> Relay2
  validArch[initConn]
}

/*************************************
 * Dataflow constraints
 ************************************/
abstract sig Data {}

one sig ActionsRest extends Data {}
one sig StatusRest extends Data {}
one sig SetPointsRest extends Data {}
one sig StatusModbus extends Data {}
one sig ActionsModbus extends Data {}
one sig Time extends Data {}

fact {
  // If a component consumes no data, then it has no consume paths
  all c: Component | no c.consume implies no c.dataflowPath and no c.dataCCPath

  // A dataflow path should be a subset of a C&C path (which contains network devices)
  all c: Component, d: c.consume | c.dataflowPath[d] in ^(c.dataCCPath[d])
}

// Dataflow view
fact {
  no Firewall.consume
  no Firewall.produce
  no Firewall.dataflow

  no Switch.consume
  no Switch.produce
  no Switch.dataflow

  all c: Printer | c.consume = StatusRest + SetPointsRest
  no Printer.produce
  no Printer.dataflow

  no VPN.consume
  no VPN.produce
  no VPN.dataflow

  no Internet.consume
  no Internet.produce
  no Internet.dataflow

  all c: SCADA {
    c.consume = ActionsRest + StatusRest + SetPointsRest
    c.produce = ActionsRest
    c.dataflow = HMI + EngWorkstation + OPC + Historian
  }

  all c: OPC {
    c.consume = ActionsRest + StatusModbus
    c.produce = StatusRest + ActionsModbus
    c.dataflow = SCADA + HMI + Relay
  }

  all c: HMI {
    c.consume = StatusRest
    c.produce = SetPointsRest
    c.dataflow = SCADA + OPC + Printer
  }

  all c: EngWorkstation {
    c.consume = StatusRest + SetPointsRest
    c.produce = SetPointsRest
    c.dataflow = SCADA
  }

  all c: Historian | c.consume = Time + StatusRest + ActionsRest + SetPointsRest
  no Historian.produce
  no Historian.dataflow

  no NTP.consume
  all c: NTP {
    c.produce = Time
    c.dataflow = Historian
  }

  no RTU.consume
  all c: RTU {
    c.produce = StatusModbus
    c.dataflow = OPC
  }

  all c: Relay | c.consume = ActionsModbus
  no Relay.produce
  no Relay.dataflow
}

/*************************************
 * Functional constraints
 ************************************/
abstract sig Function {}
one sig TransFunc extends Function {}
one sig PrintFunc extends Function {}
one sig HistoryFunc extends Function {}

pred transFunc[conn: Component -> Component] {
  some c: OPC | dataSatisfied[c, conn]
  some c: HMI | dataSatisfied[c, conn]
  some c: SCADA | dataSatisfied[c, conn]
  some c: RTU | dataSatisfied[c, conn]
  some c: Relay | dataSatisfied[c, conn]
}

pred printFunc[conn: Component -> Component] {
  some c: Printer | dataSatisfied[c, conn]
}

pred historyFunc[conn: Component -> Component] {
  some c: Historian | dataSatisfied[c, conn]
}

/*************************************
 * Solving goals
 ************************************/
fact {
  Printer1 in Compromised
  // Can go k=2 steps
  let k_transitive = initConn + initConn.initConn |
    all c: Component | c in Printer1.k_transitive iff c in Compromised
}

sig AvailFunction in Function {}

soft[1] fact {
  TransFunc in AvailFunction
  PrintFunc in AvailFunction
  HistoryFunc in AvailFunction
}

run GracefulDegrade {
  validArch[degradedConn]
  
  TransFunc in AvailFunction implies transFunc[degradedConn]
  PrintFunc in AvailFunction implies printFunc[degradedConn]
  HistoryFunc in AvailFunction implies historyFunc[degradedConn]

  maxsome degradedConn & initConn
  softno degradedConn - initConn
} for 26 Component

/*************************************
 * Helper functions
 ************************************/
pred shouldConnectTo[src: Component, dst: Component, conn: Component -> Component] {
  all c': Component | src -> c' in conn implies c' in dst
}

pred dataSatisfied[c: Component, conn: Component -> Component] {
  all d: c.consume | some p: Component {
    d in p.produce
    dataCanFlow[p, c, d]
    safePath[p, c, d, conn]
  }
}

pred dataCanFlow[producer, consumer: Component, d: Data] {
  let path = consumer.dataflowPath[d] {
    path in dataflow
    producer = consumer or producer -> consumer in ^path
  }
}

pred safePath[producer, consumer: Component, d: Data, conn: Component -> Component] {
  let path = consumer.dataCCPath[d] {
    path in conn
    producer -> consumer in ^path
    no path.Component & Compromised
    no Component.path & Compromised
  }
}
