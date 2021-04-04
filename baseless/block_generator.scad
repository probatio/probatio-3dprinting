mm = 1;

module probatio_block( x, y, part="both",
                     // changing the below defaults will likely break the model
                     , block_unit = 50 * mm
                     , block_wall_thickness = 2 * mm
                     , block_top_height = 15.5 * mm
                     , block_fillet_radius = 2 * mm
                     )
{
    assert(x >= 1, "Probatio block x dimension must be at least one");
    assert(y >= 1, "Probatio block x dimension must be at least one");
        
    outer_origin = 0;
    outer_x = block_unit * x;
    outer_y = block_unit * y;
    inner_origin = block_wall_thickness;
    inner_x = block_unit * x - block_wall_thickness;
    inner_y = block_unit * y - block_wall_thickness;
    corner_midpoint = [for (i = [1,2,3] ) block_unit / 2];
    block_midpoint =  [block_unit * x / 2, block_unit * y / 2, block_unit / 2];
    block_bottom_height = block_unit - block_top_height;

    // panel cut parameters
    bolt_head_radius = 6 * mm / 2;
    bolt_head_height = 1.7 * mm;
    bolt_nominal_radius = 3 * mm / 2;
    bolt_length = 8 * mm;
    top_to_top_gap = 1 * mm;
    side_to_top_gap = 0.5 * mm;
    pin_radius = 2.6 * mm / 2;
    slot_radius = 3 * mm / 2;
    pin_to_slot_gap = 0.4 * mm;
    pin_to_pin_gap = 0.8 * mm;
    magnet_radius = 4 * mm / 2;
    magnet_well_radius = magnet_radius + 0.2 * mm;
    magnet_thickness = 2 * mm;
    magnet_wall_thickness = 0.5 * mm;
    
    // panel cut derived positions
    bolt_x = corner_midpoint.x;
    bolt_y = block_top_height - top_to_top_gap - bolt_head_radius;
    slot_x = block_top_height + side_to_top_gap + slot_radius;
    pins_x = slot_x + slot_radius + pin_to_slot_gap + pin_radius;
    top_pin_y = block_top_height - top_to_top_gap - pin_radius;
    bottom_pin_y = top_pin_y - 2 * pin_to_pin_gap - 4 * pin_radius;
    middle_pin_y = (top_pin_y + bottom_pin_y) / 2;
    slot_top_y = block_top_height;
    slot_bottom_y = bottom_pin_y;
    magnet_x = block_top_height - side_to_top_gap - magnet_radius;
    magnet_y = middle_pin_y;
    second_half_translation = 
        [ bolt_x + bolt_head_radius + pin_radius 
            - block_top_height - slot_radius - side_to_top_gap
        , 0
        , 0
        ];
    assert(second_half_translation.x == 11.8 * mm
          , "Based on solvespace prototype"
          );

    module half_block_basis ()
    {
        union () 
        {
            difference()
            {
                // outer half block
                linear_extrude(height=block_unit, center=false)
                    polygon
                    ([ [outer_origin, outer_origin]
                     , [outer_origin, outer_y]
                     , [outer_x,      outer_origin]
                    ]);
                
                // inner half block (hollow)
                hollow_height = block_unit - 2*block_wall_thickness;
                translate([0,0,block_wall_thickness])
                    linear_extrude(height=hollow_height, center=false)
                        polygon
                        ([ [inner_origin, inner_origin]
                         , [inner_origin, inner_y]
                         , [inner_x,      inner_origin]
                        ]);
            }
        }
    }
    
    // for centering a repositioning elements while performing transformations
    // about the global origin such as rotations and mirrors
    module corner_centered()
    {
        translate(-corner_midpoint) children();
    }
    
    module block_centered()
    {
        translate(-block_midpoint) children();
    }
    
    module corner_repositioned()
    {
        translate(corner_midpoint) children();
    }
    
    module block_repositioned()
    {
        translate(block_midpoint) children();
    }

    module corner_rotate(deg, axis)
    {
        corner_repositioned() 
            rotate(a=deg, v=axis) 
                corner_centered() 
                    children();
    }
    
    module block_rotate(deg, axis)
    {
        block_repositioned() 
            rotate(a=deg, v=axis) 
                block_centered() 
                    children();
    }
    
    module half_pins()
    {
        pins = [ [pins_x, top_pin_y, 0]
               , [pins_x, middle_pin_y, 0]
               , [pins_x, bottom_pin_y, 0] 
               ];
        for (pin = pins) translate(pin) 
            cylinder(h=block_wall_thickness, r=pin_radius);
    }
    
    module slot()
    {
        slot_extents = [ [slot_x, slot_top_y, 0]
                       , [slot_x, slot_bottom_y, 0] 
                       ];
        hull()
            for (slot_position = slot_extents) translate(slot_position)
                cylinder(h=block_wall_thickness, r=slot_radius);
    }
    
    module pins()
    {
        half_pins();
        translate(second_half_translation) half_pins();
    }
    
    module slots()
    {
        slot();
        translate(second_half_translation) slot();
    }
    
    module left_magnet()
    {
        translate([magnet_x, magnet_y, magnet_wall_thickness])
            cylinder( h = block_wall_thickness - magnet_wall_thickness
                    , r1 = magnet_well_radius
                    , r2 = magnet_radius
                    );
    }

    module right_magnet()
    {
        corner_repositioned()
            mirror([1,0,0]) corner_centered() left_magnet();
    }

    module magnets()
    {
        left_magnet(); right_magnet();
    }
    
    module bolt()
    {
        translate([bolt_x, bolt_y, 0]) union()
        {
            // head
            cylinder( h = bolt_head_height
                    , r1 = bolt_head_radius
                    , r2 = bolt_nominal_radius
                    );
    
            // shaft
            cylinder( h = bolt_length
                    , r = bolt_nominal_radius
                    );
            
        }
    }
    
    module one_connector()
    {
        slots();
        magnets();
        bolt();
    }
    
    module connector_panel_cuts()
    {
        for (deg = [0,90,180,270]) corner_rotate(deg, [0,0,1]) one_connector();
        corner_rotate(90, [0,0,1]) pins();
    }

    module half_side_connector_cuts()
    {
        xs = [0 : 1: x-1];
        ys = [0 : 1: y-1];

        // left side connector panels
        for (j = ys)
            translate([0, j * block_unit, 0])
                corner_rotate(90, [0,1,0]) 
                    connector_panel_cuts();
        
        // front side connector panels
        for (i = xs)
            translate([i * block_unit, 0, 0])
                corner_rotate(90, [0,0,1]) 
                    corner_rotate(90, [0,1,0])
                        connector_panel_cuts();
    }

    module bottom_connector_cuts()
    {
        xs = [0 : 1: x-1];
        ys = [0 : 1: y-1];
        for (i = xs) for (j = ys)
        {
            translate([i * block_unit, j * block_unit, 0])
                connector_panel_cuts();
        }
    }

    module half_handle_cuts()
    {
        handle_radius = 13.5 * mm / 2;
        xs = [0 : 1: x];
        ys = [0 : 1: y];
        for (z = [0, block_unit]) 
        {
            for (i = xs) 
                translate([i * block_unit, 0, z])
                    sphere(handle_radius);
            for (j = ys) 
                translate([0, j * block_unit, z])
                    sphere(handle_radius);
        }
    }

    module half_block()
    {
        difference()
        {
            half_block_basis();
            half_side_connector_cuts();
            half_handle_cuts();
        }
    }

    module full_block()
    {
        difference()
        {
            union() 
            {
                half_block();
                block_rotate(180, [0,0,1]) half_block();
            }
            bottom_connector_cuts();
        }
    }

    module fillets()
    {
        corners = [ [inner_origin, inner_origin, inner_origin]
                  , [inner_origin, inner_y,      inner_origin]
                  , [inner_x,      inner_origin, inner_origin]
                  , [inner_x,      inner_y,      inner_origin]
                  ];
        hull()
        {
            for (corner = corners)
            {
                translate(corner)
                {
                    sphere(r=block_fillet_radius);
                    cylinder(h=block_unit, r=block_fillet_radius);   
                }
            }
        }
    }

    module block_top()
    {
        color("red") intersection()
        {
            full_block();
            translate([0, 0, block_bottom_height])
                cube([outer_x, outer_y, block_top_height]);
            fillets();
        }
    }

    module block_bottom()
    {
        color("silver") intersection()
        {
            full_block();
            cube([outer_x, outer_y, block_bottom_height]);
            fillets();
        }
    }

    module connector_pcb_outline()
    {
        pcb_thickness = 1.6 * mm;
        difference()
        {
            translate([ inner_origin + pcb_thickness
                      , inner_origin + pcb_thickness
                      , 0])
                cube([ inner_x - inner_origin - 2*pcb_thickness
                     , inner_y - inner_origin - 2*pcb_thickness
                     , pcb_thickness]);

            scale([1,1,100]) translate([0,0,-block_wall_thickness/2])
            for (deg = [0, 90, 180, 270]) corner_rotate(deg, [0,0,1])
            {
                hull()
                {
                    right_magnet();
                    translate([0,-block_top_height,0]) right_magnet();
                    translate([block_top_height,0,0]) right_magnet();
                }
                hull()
                {
                    left_magnet();
                    translate([0,-block_top_height,0]) left_magnet();
                    translate([-block_top_height,0,0]) left_magnet();
                }
            }
            connector_panel_cuts();
        }
    }

    if (part == "both")
    {
        block_top();
        block_bottom();
    }
    else if (part == "top")
        block_top();
    else if (part == "bottom")
        block_bottom();
    else if (part == "pcb")
        projection() connector_pcb_outline();
}
