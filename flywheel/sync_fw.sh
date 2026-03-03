#!/bin/bash
fw sync -y --include dicom fw://crl/fetalbrain-P00041916 /lab-share/Rad-Warfield-e2/Groups/fetalmri/scans/flywheel
fw sync -y --include dicom fw://rollins/rollinsfetal-P00008836 /lab-share/Rad-Warfield-e2/Groups/fetalmri/scans/flywheel
