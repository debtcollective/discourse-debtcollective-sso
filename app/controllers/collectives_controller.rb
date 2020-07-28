class Debtcollective::CollectivesController < ApplicationController
  before_action :ensure_logged_in
  before_action :find_category

  def join
    # return error if category is not a collective
    if !is_collective?(@category)
      return render json: failed_json, status: 400
    end

    group = collective_group(@category)

    # return error if group not found
    if !group
      return render json: failed_json, status: 400
    end

    # add to group
    group.add(current_user)
    group.save!

    # use group notification level for the category
    category_id = @category.id
    notification_level = group.default_notification_level
    CategoryUser.set_notification_level_for_category(current_user, notification_level, category_id)

    render json: success_json
  end

  protected

  def find_category
    @category = Category.find(params[:id])
  end

  def is_collective?(category)
    !!category.custom_fields["tdc_is_collective"]
  end

  def collective_group(collective)
    collective.groups.where.not(id: Group::AUTO_GROUPS.values).first
  end
end
