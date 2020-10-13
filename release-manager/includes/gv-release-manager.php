<?php
/**
 * GravityView Release Manager
 *
 * @since     1.0.0
 *
 * @license   GPL2+
 * @author    Katz Web Services, Inc.
 * @link      http://gravityview.co
 * @copy      Copyright 2020, Katz Web Services, Inc.
 *
 * @package   GravityView_Release_Manager
 */

namespace GV_Release_Manager;

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! class_exists( 'WP_List_Table' ) ) {
	require_once( ABSPATH . 'wp-admin/includes/class-wp-list-table.php' );
}

class Release_Manager extends \WP_List_Table {

	const DEFAULT_ORDER_BY = 'gh_commit_timestamp';

	const DEFAULT_ORDER = 'desc';

	const DEFAULT_PER_PAGE = 20;

	const NONCE_ACTION = 'gv_release_manager_nonce';

	const OPTION_SETTINGS = 'gv_release_manager_settings';

	const OPTION_RELEASES = 'gv_release_manager_releases';

	private $settings;

	/**
	 * @inheritDoc
	 *
	 * @since 1.0.0
	 */
	public function __construct() {

		add_action( 'admin_menu', [ $this, 'add_admin_menu' ] );
		add_action( 'admin_enqueue_scripts', [ $this, 'maybe_enqueue_ui_assets' ] );
		add_action( 'wp_ajax_gv_release_manager_ajax_handle_request', [ $this, 'ajax_response' ] );
		add_action( 'rest_api_init', [ $this, 'register_rest_routes' ] );
	}

	/**
	 * Initialize \WP_List_Table class by running constructor
	 *
	 * @since 1.0.0
	 *
	 * @return void
	 */
	private function init_wp_list() {

		parent::__construct( [
			'singular' => 'release',
			'plural'   => 'releases',
			'ajax'     => true,
		] );
	}

	/**
	 * Add GV Release Manager to WP admin menu
	 *
	 * @since 1.0.0
	 *
	 * @return void
	 */
	public function add_admin_menu() {

		/**
		 * @filter `gv_release_manager/access/capability` Set custom capability for admin menu access
		 * @since  1.0.0
		 */
		$capability = apply_filters( 'gv_release_manager/access/capability', 'edit_products' );

		add_submenu_page(
			'edit.php?post_type=download',
			'GravityView Release Manager',
			'Manage Releases',
			$capability,
			'gv_release_manager',
			[ $this, 'admin_menu_init' ]
		);
	}

	/**
	 * Register REST routes used to add releases/etc.
	 *
	 * @since 1.0.0
	 *
	 * @return void
	 */
	public function register_rest_routes() {

		$REST_controller = new REST_Controller();
		$REST_controller->register_routes();
	}

	/**
	 * Render table and perform other actions when accessing the plugin form WP admin menu
	 *
	 * @since 1.0.0
	 *
	 * @return void
	 */
	public function admin_menu_init() {

		$this->init_wp_list();

		$this->maybe_save_settings();

		$title           = esc_html( get_admin_page_title() );
		$nonce_field     = wp_nonce_field( self::NONCE_ACTION );
		$auth_token      = $this->get_setting( 'auth_token' );
		$storage_path    = $this->get_setting( 'storage_path' );
		$wp_upload_path  = wp_upload_dir()['basedir'];
		$_GET['orderby'] = ! empty( $_GET['orderby'] ) ? $_GET['orderby'] : self::DEFAULT_ORDER_BY;

		ob_start();

		$this->prepare_items();
		$this->display();

		$releases = ob_get_clean();

		echo <<<HTML
<div class="wrap">
	<h1>${title}</h1>

	<form method="post">
		<input type="hidden" name="action" value="gv_release_manage_save_settings">
		${nonce_field}

		<table class="form-table" role="presentation">
			<tbody>
				<tr class="form-field">
					<th style="width: 10em;" scope="row">
						<label for="auth_token">Authorization Token:</label>
					</th>
					<td>
						<input type="text" name="auth_token" id="auth_token" value="${auth_token}" style="width: 20em;">
					</td>
				</tr>
				<tr class="form-field">
					<th style="width: 10em;" scope="row">
						<label for="auth_token">Storage Path:</label>
					</th>
					<td>
						<i>${wp_upload_path}</i>/<input type="text" name="storage_path" id="storage_path" value="${storage_path}" style="width: 20em;">
						<p class="submit">
							<input type="submit" id="save_settings" class="button button-primary" value="Save Settings">
						</p>
					</td>
				</tr>
			</tbody>
		</table>
	</form>

	<hr />

	<form id="gv-releases" method="get">
		${releases}
	</form>
</div>
HTML;
	}

	/**
	 * @inheritDoc
	 *
	 * @since 1.0.0
	 */
	public function get_columns() {

		return [
			'plugin_name'         => 'Plugin',
			'plugin_version'      => 'Version',
			'gh_commit_tag'       => 'GH Tag',
			'gh_commit_timestamp' => 'GH Commit Date',
			'gh_commit_url'       => 'GH Commit Hash',
			'build_file'          => 'Release Download',
			'ci_job_url'          => 'CI Job',
		];
	}

	/**
	 * @inheritDoc
	 *
	 * @since 1.0.0
	 */
	protected function column_default( $row, $column ) {

		switch ( $column ) {
			case 'plugin_name':
				return sprintf( '<a href="https://github.com/gravityview/%s">%s</a>', trim( explode( '/commit', basename( $row[ $column ] ) )[0] ), $row[ $column ] );
			case 'gh_commit_timestamp':
				return date_i18n( 'F j, Y @ H:i:s', $row[ $column ] );
			case 'gh_commit_url':
				return sprintf( '<a href="%s">%s</a>', $row[ $column ], basename( $row[ $column ] ) );
			case 'ci_job_url':
				return ! empty( $row[ $column ] ) ? sprintf( '<a href="%s">Link</a>', $row[ $column ] ) : 'N/A';
			case 'build_file':
				$build_file = ! empty( $row[ $column ] ) ? $row[ $column ] : '';

				$build_file_with_path = sprintf( '%s/%s', $this->get_setting( 'storage_path' ), $build_file );

				return is_file( sprintf( '%s/%s', wp_upload_dir()['basedir'], $build_file_with_path ) )
					? sprintf( '<a href="%s/%s">Link</a>', wp_upload_dir()['baseurl'], $build_file_with_path )
					: 'N/A';
			default:
				return ! empty( $row[ $column ] ) ? $row[ $column ] : 'N/A';
		}
	}

	/**
	 * @inheritDoc
	 *
	 * @since 1.0.0
	 */
	protected function get_sortable_columns() {

		return [
			'plugin_name'         => [ 'plugin_name', false ],
			'plugin_version'      => [ 'plugin_version', false ],
			'gh_commit_timestamp' => [ 'gh_commit_timestamp', false ],
		];
	}

	/**
	 * @inheritDoc
	 *
	 * @since 1.0.0
	 */
	public function prepare_items() {

		$this->_column_headers = [
			$this->get_columns(),
			[], // hidden columns
			$this->get_sortable_columns(),
		];

		$items = self::get_releases();

		usort( $items, [ $this, 'usort_reorder' ] );

		$per_page     = self::DEFAULT_PER_PAGE;
		$current_page = $this->get_pagenum();
		$total_items  = count( $items );

		// Handle pagination
		$paged_items = array_slice( $items, ( ( $current_page - 1 ) * $per_page ), $per_page );
		$this->items = $paged_items;

		$this->set_pagination_args( [
			'total_items' => $total_items,
			'per_page'    => $per_page,
			'total_pages' => ceil( $total_items / $per_page ),
			'orderby'     => ! empty( $_REQUEST['orderby'] ) && '' !== $_REQUEST['orderby'] ? $_REQUEST['orderby'] : self::DEFAULT_ORDER_BY,
			'order'       => ! empty( $_REQUEST['order'] ) && '' !== $_REQUEST['order'] ? $_REQUEST['order'] : self::DEFAULT_ORDER,
		] );
	}

	/**
	 * @inheritDoc
	 */
	public function display() {

		$this->rename_items_to_releases();

		echo '<input type="hidden" id="order" name="order" value="' . $this->_pagination_args['order'] . '" />';
		echo '<input type="hidden" id="orderby" name="orderby" value="' . $this->_pagination_args['orderby'] . '" />';

		parent::display();
	}

	/**
	 * @inheritDoc
	 *
	 * @since 1.0.0
	 */
	public function ajax_response() {

		check_ajax_referer( self::NONCE_ACTION );

		$this->init_wp_list();

		$this->prepare_items();

		extract( $this->_args );
		extract( $this->_pagination_args, EXTR_SKIP );

		$this->rename_items_to_releases();

		ob_start();
		if ( ! empty( $_REQUEST['no_placeholder'] ) ) {
			$this->display_rows();
		} else {
			$this->display_rows_or_placeholder();
		}
		$rows = ob_get_clean();

		ob_start();
		$this->print_column_headers();
		$headers = ob_get_clean();

		ob_start();
		$this->pagination( 'top' );
		$pagination_top = ob_get_clean();

		ob_start();
		$this->pagination( 'bottom' );
		$pagination_bottom = ob_get_clean();

		$response                         = [ 'rows' => $rows ];
		$response['pagination']['top']    = $pagination_top;
		$response['pagination']['bottom'] = $pagination_bottom;
		$response['column_headers']       = $headers;

		wp_send_json( $response );
	}

	/**
	 * @inheritDoc
	 *
	 * @since 1.0.0
	 */
	public function no_items() {

		echo 'No releases found.';
	}

	/**
	 * Sort data
	 *
	 * @since 1.0.0
	 *
	 * @param string $a First value
	 * @param string $b Second value
	 *
	 * @return int
	 */
	private function usort_reorder( $a, $b ) {

		$orderby = ! empty( $_REQUEST['orderby'] ) ? wp_unslash( $_REQUEST['orderby'] ) : self::DEFAULT_ORDER_BY;

		$order = ! empty( $_REQUEST['order'] ) ? wp_unslash( $_REQUEST['order'] ) : 'asc';

		$result = strcmp( $a[ $orderby ], $b[ $orderby ] );

		return ( 'asc' === $order ) ? $result : - $result;
	}

	/*
	 * We're dealing with releases, not items :)
	 *
	 * @since 1.0.0
	 *
	 * @return void
	 */
	private function rename_items_to_releases() {

		add_filter( 'ngettext', function ( $translation, $single, $plural, $number ) {

			if ( '%s item' !== $single ) {
				return $translation;
			}

			return $number === 1 ? "${number} release" : "${number} releases";
		}, 10, 4 );
	}

	/**
	 * Enqueue UI assets on plugin's page
	 *
	 * @since 1.0.0
	 *
	 * @return void
	 */
	public function maybe_enqueue_ui_assets() {

		$screen = get_current_screen();

		if ( 'download_page_gv_release_manager' !== $screen->id ) {
			return;
		}

		$options = [
			'default_order'    => self::DEFAULT_ORDER,
			'default_order_by' => self::DEFAULT_ORDER_BY,
		];

		wp_enqueue_script( 'gv-release-manager', plugin_dir_url( dirname( __FILE__ ) ) . 'assets/gv-release-manager.js', [], null, true );
		wp_localize_script( 'gv-release-manager', 'GV_RELEASE_MANAGER', $options );
	}

	/**
	 * Process POST request and conditionally save settings
	 *
	 * @return void
	 */
	public function maybe_save_settings() {

		if ( empty( $_POST ) || ! isset( $_POST['action'] ) || 'gv_release_manage_save_settings' !== $_POST['action'] || ! isset( $_POST['_wpnonce'] ) || ! wp_verify_nonce( $_POST['_wpnonce'], self::NONCE_ACTION ) ) {
			return;
		}

		$settings = $this->get_settings();

		$new_settings = array_map( 'esc_attr', $_POST );

		// Save token
		if ( ! empty( $new_settings['auth_token'] ) ) {
			$settings['auth_token'] = $new_settings['auth_token'];
		}

		// Save storage path
		if ( ! empty( $new_settings['storage_path'] ) ) {
			$new_storage_path = sprintf( '%s/%s', wp_upload_dir()['basedir'], $new_settings['storage_path'] );

			if ( ! empty( $settings['storage_path'] ) && $settings['storage_path'] !== $new_settings['storage_path'] ) {
				$storage_path = sprintf( '%s/%s', wp_upload_dir()['basedir'], $settings['storage_path'] );

				# Rename storage path if it exists
				if ( is_dir( $storage_path ) ) {
					rename( $storage_path, $new_storage_path );
				}
			} elseif ( ! is_dir( $new_storage_path ) ) {
				mkdir( $new_storage_path );
			}

			$settings['storage_path'] = $new_settings['storage_path'];
		}

		$this->save_settings( $settings );
	}

	/**
	 * Get all plugin settings
	 *
	 * @since 1.0.0
	 *
	 * @param array $release_data Release data
	 *
	 * @return array Settings
	 */
	public function get_settings() {

		if ( ! $this->settings ) {
			$settings = get_option( self::OPTION_SETTINGS );

			$this->settings = $settings ? $settings : [];
		}

		return $this->settings;
	}

	/**
	 * Get single plugin setting
	 *
	 * @since 1.0.0
	 *
	 * @param string $setting Setting
	 *
	 * @return string Setting value or empty string
	 */
	public function get_setting( $setting ) {

		$settings = $this->get_settings();

		return isset( $settings[ $setting ] ) ? $settings[ $setting ] : '';
	}

	/**
	 * Save all plugin settings
	 *
	 * @since 1.0.0
	 *
	 * @param array $settings Setting
	 *
	 * @return void
	 */
	public function save_settings( $settings = [] ) {

		update_option( self::OPTION_SETTINGS, $settings );

		$this->settings = $settings;
	}

	/**
	 * Save single plugin setting
	 *
	 * @since 1.0.0
	 *
	 * @param array $setting Setting
	 *
	 * @return void
	 */
	public function save_setting( $setting = [] ) {

		$settings = $this->get_settings();

		$settings = array_merge( $settings, $setting );

		$this->save_settings( $settings );
	}

	/**
	 * Get available releases
	 *
	 * @since 1.0.0
	 *
	 * @return array
	 */
	public function get_releases() {

		$releases = get_option( self::OPTION_RELEASES );

		return $releases ? $releases : [];
	}

	/**
	 * Add new release
	 *
	 * @since 1.0.0
	 *
	 * @param array $release_data Release data
	 *
	 * @return true|\WP_Error
	 */
	public function add_new_release( $release_data = [] ) {

		$required_properties = [
			'plugin_name',
			'plugin_version',
			'gh_commit_tag',
			'gh_commit_timestamp',
			'gh_commit_url',
			'ci_job_url',
			'build_hash',
		];

		$release_data = array_map( 'esc_attr', $release_data );

		foreach ( $required_properties as $property ) {
			if ( ! isset( $release_data[ $property ] ) ) {
				return new \WP_Error( 'missing_data', "'${property}' property is missing." );
			}
		}

		try {
			$release_data['build_file'] = $this->process_build_upload( $release_data );
		} catch ( \Exception $e ) {
			return new \WP_Error( 'upload_fail', "Build file upload failed: {$e->getMessage()}" );
		}

		$release_data['_id'] = wp_generate_password(5); // set unique ID in order to overwrite the option (WP's update_option otherwise rejects duplicate)

		$id = substr( md5( sprintf( '%s-%s-%s', $release_data['plugin_name'], $release_data['plugin_version'], $release_data['gh_commit_tag'] )), 0, 5 );

		$releases        = self::get_releases();
		$releases[ $id ] = $release_data;

		$result = update_option( self::OPTION_RELEASES, $releases );

		return $result ? $result : new \WP_Error( 'save_error', 'Failed to save the release.' );
	}

	/**
	 * Process uploaded build file
	 *
	 * @since 1.0.0
	 *
	 * @param array $release_data Release data
	 *
	 * @return string Build filename
	 *
	 * @throws \Exception
	 */
	private function process_build_upload( $release_data = [] ) {

		$build_file      = ! empty( $_FILES['build_file']['tmp_name'] ) ? $_FILES['build_file']['tmp_name'] : null;
		$build_file_name = ! empty( $_FILES['build_file']['name'] ) ? $_FILES['build_file']['name'] : null;
		$build_hash      = ! empty( $release_data['build_hash'] ) ? $release_data['build_hash'] : null;

		$settings = $this->get_settings();

		if ( ! $build_file || ! $build_hash || md5_file( $build_file ) !== $build_hash ) {

			throw new \Exception( 'build does not exist or failed hash validation' );
		}

		$_save_storage_path = false;
		if ( empty( $settings['storage_path'] ) ) {

			$settings['storage_path'] = wp_generate_password( 25, false );
			$_save_storage_path       = true;
		}

		$upload_folder = sprintf( '%s/%s', wp_upload_dir()['basedir'], $settings['storage_path'] );

		if ( ! is_dir( $upload_folder ) && ! mkdir( $upload_folder ) ) {
			throw new \Exception( "could not create an upload folder {$upload_folder}" );
		}

		if ( ! move_uploaded_file( $build_file, sprintf( '%s/%s', $upload_folder, $build_file_name ) ) ) {
			throw new \Exception( "could save build file in {$upload_folder}" );
		}

		if ( $_save_storage_path ) {
			$this->save_setting( [ 'storage_path' => $settings['storage_path'] ] );
		}

		return $build_file_name;
	}
}
