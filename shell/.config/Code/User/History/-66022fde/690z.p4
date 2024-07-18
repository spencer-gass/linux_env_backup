/* -*- P4_16 -*- */
#include <core.p4>
#include <xsa.p4>

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<8>  port_t;

struct user_metadata_t {
    port_t ing_port;
    port_t egr_spec;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser FRRdplaneParser(packet_in packet,
                inout user_metadata_t user_meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition accept;
    }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control FRRdplaneIngress(
                  inout user_metadata_t user_meta,
                  inout standard_metadata_t standard_metadata) {

    apply {
        user_meta.egr_spec = user_meta.ingress_port;
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control FRRdplaneDeparser(packet_out packet,
                          in headers hdr,
                          inout user_metadata_t user_meta,
                          inout standard_metadata_t standard_metadata) {
    apply {
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

XilinxPipeline(
FRRdplaneParser(),
FRRdplaneIngress(),
FRRdplaneDeparser()
) main;
