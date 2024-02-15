/****************************************************************************************************************
 *
 *  Copyright (c) 2023 OCLC, Inc. All Rights Reserved.
 *
 *  OCLC proprietary information: the enclosed materials contain
 *  proprietary information of OCLC, Inc. and shall not be disclosed in whole or in
 *  any part to any third party or used by any person for any purpose, without written
 *  consent of OCLC, Inc.  Duplication of any portion of these materials shall include this notice.
 *
 ******************************************************************************************************************/

import { action } from "@storybook/addon-actions";
import { type Meta, type Story } from "@storybook/react";

import Component, { type ComponentProps } from "./Component";

export default {
    title: "Circ/Component",
    component: Component,
    args: {},
} as Meta;

const Template: Story<Component> = (args) => <Component {...args} />;

export const Default = Template.bind({});
Default.args = {
};
