require "test_helper"

class Accounts::ShoppingListItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @session = sessions(:one)
    @item = shopping_list_items(:salmon)
  end

  def account_path_prefix
    "/#{@account.external_account_id}"
  end

  test "should toggle item checked status" do
    sign_in_as(@session)
    assert_not @item.checked

    patch "#{account_path_prefix}/shopping_list_items/#{@item.id}/toggle"
    assert_response :redirect
    assert @item.reload.checked
  end

  test "should toggle item back to unchecked" do
    sign_in_as(@session)
    @item.update!(checked: true)

    patch "#{account_path_prefix}/shopping_list_items/#{@item.id}/toggle"
    assert_response :redirect
    refute @item.reload.checked
  end

  test "should destroy item" do
    sign_in_as(@session)

    assert_difference "ShoppingListItem.count", -1 do
      delete "#{account_path_prefix}/shopping_list_items/#{@item.id}"
    end

    assert_response :redirect
  end
end
