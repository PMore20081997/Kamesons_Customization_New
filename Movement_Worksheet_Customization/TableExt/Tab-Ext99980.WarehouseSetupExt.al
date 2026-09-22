tableextension 99980 WarehouseSetupExt extends "Warehouse Setup"
{
    fields
    {
        field(99971; "MAIN Warehouse"; Code[20])
        {
            Caption = 'MAIN Warehouse';
            TableRelation = Location.Code;
            DataClassification = CustomerContent;
        }
        field(99972; "RECEIVE Warehouse"; Code[20])
        {
            Caption = 'RECEIVE Warehouse';
            TableRelation = Location.Code;
            DataClassification = CustomerContent;
        }

        /// <summary>
        /// Put-Away routing priority. An item's routing types are derived from
        /// the Main-WH bins it holds Bin Content in (Bulk / Static / Flowrack),
        /// so one item can be several types at once. A receipt is filled in the
        /// order below: each type takes what its Main face can absorb, and only
        /// the remainder after all three goes to High Bay.
        ///
        /// Defaults (1=BULK, 2=Static, 3=Flowrack) are applied by
        /// "Kam Whse Setup Lookup".GetRoutingPriority() when left blank, so an
        /// unconfigured setup still behaves sensibly.
        /// </summary>
        field(99973; "Routing Priority 1"; Enum "Item Routing Type NDPP")
        {
            Caption = 'Routing Priority 1';
            DataClassification = CustomerContent;
        }
        field(99974; "Routing Priority 2"; Enum "Item Routing Type NDPP")
        {
            Caption = 'Routing Priority 2';
            DataClassification = CustomerContent;
        }
        field(99975; "Routing Priority 3"; Enum "Item Routing Type NDPP")
        {
            Caption = 'Routing Priority 3';
            DataClassification = CustomerContent;
        }
    }
}
