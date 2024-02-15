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

import { render, screen } from "@testing-library/react";
import { createWrapper, loggerWithErrorsOff, WRAPPERS } from "../../utils/testUtils";

import Component from "./Component";

describe("Component", () => {
    const renderComponent = (props, { logErrors = true } = {}) => {
        const wrapperParams = logErrors ? {} : { logger: loggerWithErrorsOff };

        render(<Component {...props} />, {
            wrapper: createWrapper([WRAPPERS.QUERY, WRAPPERS.THEME], wrapperParams),
        });
    };

    it("should display", () => {
        renderComponent();

        expect(screen.getByText("Custom Title")).toBeVisible();
    });
});
