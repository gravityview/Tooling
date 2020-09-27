<?php
/**
 * Plugin Name:        GravityView Release Manager
 * Plugin URI:         https://gravityview.co
 * Description:        Internal tool to manage GravityView ecosystem releases
 * Version:            1.0.0
 * Author:             GravityView
 * Author URI:         https://gravityview.co
 * Text Domain:        gravityview
 * License:            GPLv2 or later
 * License URI:        http://www.gnu.org/licenses/gpl-2.0.html
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

add_action( 'init', 'gv_release_manager_init' );

function gv_release_manager_init() {

	require dirname( __FILE__ ) . '/includes/gv-release-manager.php';
	require dirname( __FILE__ ) . '/includes/gv-release-rest-controller.php';

	( new GV_Release_Manager\Release_Manager() );
}
