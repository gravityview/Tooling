<?php
/**
 * GravityView Release Manager
 *
 * @since     1.0.0
 *
 * @license   GPL2+
 * @author    Katz Web Services, Inc.
 * @link      http://gravityview.co
 * @copyright Copyright 2020, Katz Web Services, Inc.
 *
 * @package   GravityView_Release_Manager
 */

namespace GV_Release_Manager;

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class REST_Controller extends \WP_REST_Controller {

	const REST_NAMESPACE = 'gv-release-manager';

	private $release_manager;

	public function __construct() {
		$this->release_manager = new Release_Manager();
	}

	/**
	 * @inheritDoc
	 *
	 * @since 1.0.0
	 */
	public function register_routes() {

		register_rest_route( self::REST_NAMESPACE, '/releases', [
			[
				'methods'             => \WP_REST_Server::CREATABLE,
				'callback'            => [ $this, 'add_new_release' ],
				'permission_callback' => [ $this, 'check_authorization' ],
			],
		] );
	}

	/**
	 * Add a new release
	 *
	 * @since 1.0.0
	 *
	 * @param WP_REST_Request $request HTTP request
	 *
	 * @return WP_REST_Response|WP_Error Response object on success or WP_Error object on failure
	 */
	public function add_new_release( $request ) {

		$result = $this->release_manager->add_new_release( $request->get_params() );

		return rest_ensure_response( $result );
	}

	/**
	 * Check for authorization token match
	 *
	 * @since 1.0.0
	 *
	 * @param WP_REST_Request $request HTTP request
	 *
	 * @return boolean
	 */
	public function check_authorization( $request ) {

		return $this->release_manager->get_setting( 'auth_token') === $request->get_header( 'Authorization' );
	}
}
